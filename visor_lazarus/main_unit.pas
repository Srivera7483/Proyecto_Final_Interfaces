unit main_unit;

{$mode objfpc}{$H+}

{==============================================================================
  PROYECTO #3 - INTERFACES GRAFICAS (INFO1128)
  UNIDAD: main_unit.pas - VISOR DE MATERIAL PARTICULADO MP 2.5 um
  Autor: Kuro_Waza / INFO1128
  Docente: Alberto Caro | Ayudante: Daniela Romero
 ==============================================================================
  Cambios de esta version:
    1. Boton 'Click' (btnChangeBg) cambia el fondo del visor. Mecanismo:
         - BuscarRecursos localiza la carpeta con las imagenes (junto al .exe,
           subiendo hasta 6 niveles y entrando a recursos/imagenes/iconos/fondos).
         - FFondos guarda la lista de img*.png; FIdx es el fondo activo.
         - El boton avanza FIdx (ciclico), recarga la imagen y repinta.
         - El dibujo se hace en Chart.OnBeforeCustomDrawBackWall, con el fondo
           escalado y guardado en cache (FBmp) para no recalcularlo en cada
           repintado.
    2. Bug 'se pega todo al apretar un boton': el envio TCP/IP se hacia en el
       hilo de la interfaz (connect bloqueante cada segundo, hasta ~2 s en
       Windows si el servidor no esta activo). Ahora lo hace un hilo aparte
       (TEnvioTcp) y la interfaz nunca espera por la red.
    3. Los botones se crean con GroupIndex = 0 para que no queden hundidos.
 ==============================================================================}

interface

uses
  Classes, SysUtils, Math, Types, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, ExtCtrls, FileUtil, TAGraph, TASeries, TALegend, TACustomSeries,
  TATypes, TAChartAxisUtils, TAChartUtils, TADrawUtils, TADrawerCanvas,
  LazSerial, ssockets;

const
  TOTAL_MUESTRAS = 30; // Ventana rodante de 30 muestras (0 .. 29)
  TCP_SERVER_IP = '127.0.0.1';
  TCP_SERVER_PORT = 5000;
  MAX_COLA_TCP = 20;   // mensajes pendientes maximos hacia el servidor

type

  { TEnvioTcp: hilo que envia las muestras al servidor TCP/IP sin bloquear la GUI }

  TEnvioTcp = class(TThread)
  private
    FLock: TRTLCriticalSection;
    FCola: TStringList;
    FEvt: PRTLEvent;
    function Tomar(out AMsg: String): Boolean;
    function Enviar(const AMsg: String): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Encolar(const AMsg: String);
    procedure Detener;
  end;

  { TFormVisor }

  TFormVisor = class(TForm)
    lblMainTitle: TLabel;
    btnSave: TSpeedButton;
    btnGridToggle: TSpeedButton;
    btnChangeBg: TSpeedButton;
    ChartVisor: TChart;
    SerieMP25: TLineSeries;
    LazSerial1: TLazSerial;
    tmrFallbackSim: TTimer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnGridToggleClick(Sender: TObject);
    procedure btnChangeBgClick(Sender: TObject);
    { Se mantiene por compatibilidad con el .lfm antiguo (no hace nada).
      El fondo ahora se dibuja en ChartVisorBackWall. }
    procedure ChartVisorAfterDrawBackWall(ASender: TChart; ACanvas: TCanvas;
      const ARect: TRect);
    procedure LazSerial1RxData(Sender: TObject);
    procedure tmrFallbackSimTimer(Sender: TObject);

  private
    { Recursos graficos }
    FRec: String;               // carpeta de recursos encontrada
    FFondos: TStringList;       // rutas de las imagenes de fondo
    FIdx: Integer;              // fondo actual
    FPic: TPicture;             // imagen de fondo original
    FBmp: TBitmap;              // fondo escalado al area del grafico (cache)
    FDiskPic: TPicture;         // logo disquete AC

    { Serie temporal }
    FSerialBuffer: AnsiString;
    FMuestras: array[0..TOTAL_MUESTRAS - 1] of Double;
    FMuestrasCount: Integer;

    { Red }
    FTcp: TEnvioTcp;

    function BuscarRecursos: String;
    function BuscarArchivo(const ANombre: String): String;
    procedure CargarGlyph(ABtn: TSpeedButton; const ANombres: array of String);
    procedure CargarRecursosGraficos;
    procedure CargarFondo;
    procedure ChartVisorBackWall(ASender: TChart; ADrawer: IChartDrawer;
      const ARect: TRect; var ADoDefaultDrawing: Boolean);
    procedure ConfigurarBotones;
    procedure InicializarGrafico;
    procedure AgregarMuestra(AValor: Double);
    procedure EnviarATcpServer(AValor: Double);
    procedure IniciarComunicacionSerial;

  public

  end;

var
  FormVisor: TFormVisor;

implementation

{$R *.lfm}

{ ============================ TEnvioTcp ====================================== }

constructor TEnvioTcp.Create;
begin
  inherited Create(True);          // creado suspendido: se inicializa antes de correr
  FreeOnTerminate := True;
  InitCriticalSection(FLock);
  FCola := TStringList.Create;
  FEvt := RTLEventCreate;
  Start;
end;

destructor TEnvioTcp.Destroy;
begin
  RTLEventDestroy(FEvt);
  FCola.Free;
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TEnvioTcp.Encolar(const AMsg: String);
begin
  EnterCriticalSection(FLock);
  try
    while FCola.Count >= MAX_COLA_TCP do
      FCola.Delete(0);             // descarta lo mas antiguo si el servidor no responde
    FCola.Add(AMsg);
  finally
    LeaveCriticalSection(FLock);
  end;
  RTLEventSetEvent(FEvt);
end;

procedure TEnvioTcp.Detener;
begin
  Terminate;
  RTLEventSetEvent(FEvt);          // despierta el hilo; se libera solo (FreeOnTerminate)
end;

function TEnvioTcp.Tomar(out AMsg: String): Boolean;
begin
  AMsg := '';
  EnterCriticalSection(FLock);
  try
    Result := FCola.Count > 0;
    if Result then
    begin
      AMsg := FCola[0];
      FCola.Delete(0);
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TEnvioTcp.Enviar(const AMsg: String): Boolean;
var
  sock: TInetSocket;
begin
  Result := False;
  try
    sock := TInetSocket.Create(TCP_SERVER_IP, TCP_SERVER_PORT); // el constructor conecta
    try
      sock.WriteBuffer(AMsg[1], Length(AMsg));
      Result := True;
    finally
      sock.Free;
    end;
  except
    // servidor no disponible: se ignora, se reintenta con la proxima muestra
  end;
end;

procedure TEnvioTcp.Execute;
var
  msg: String;
begin
  while not Terminated do
  begin
    RTLEventWaitFor(FEvt, 1000);
    RTLEventResetEvent(FEvt);
    while (not Terminated) and Tomar(msg) do
    begin
      if not Enviar(msg) then
      begin
        // sin servidor: vaciar la cola para no acumular muestras viejas
        EnterCriticalSection(FLock);
        try
          FCola.Clear;
        finally
          LeaveCriticalSection(FLock);
        end;
        Break;
      end;
    end;
  end;
end;

{ ============================ TFormVisor ===================================== }

{------------------------------------------------------------------------------
  FormCreate: Inicializacion de la ventana, carga de recursos y configuracion
 ------------------------------------------------------------------------------}
procedure TFormVisor.FormCreate(Sender: TObject);
begin
  Caption := 'By Alberto Caro';
  DoubleBuffered := True;
  FMuestrasCount := 0;
  FSerialBuffer := '';
  FIdx := 0;

  FFondos := TStringList.Create;
  FPic := TPicture.Create;
  FDiskPic := TPicture.Create;

  // 1. Cargar imagenes e iconos
  CargarRecursosGraficos;

  // 2. Configurar TAChart, serie, ejes y leyendas
  InicializarGrafico;

  // 3. Botones y eventos asignados por codigo (no dependen del .lfm)
  ConfigurarBotones;
  ChartVisor.OnBeforeCustomDrawBackWall := @ChartVisorBackWall;

  // 4. Mostrar el primer fondo
  CargarFondo;

  // 5. Hilo de envio TCP/IP (no bloquea la interfaz)
  FTcp := TEnvioTcp.Create;

  // 6. Iniciar componente serial TLazSerial (COM2, 9600-8N1)
  IniciarComunicacionSerial;
end;

{------------------------------------------------------------------------------
  FormDestroy: Liberacion de recursos
 ------------------------------------------------------------------------------}
procedure TFormVisor.FormDestroy(Sender: TObject);
begin
  tmrFallbackSim.Enabled := False;
  try
    if LazSerial1.Active then
      LazSerial1.Close;
  except
  end;

  if Assigned(FTcp) then
  begin
    FTcp.Detener;                  // el hilo se libera solo
    FTcp := nil;
  end;

  FreeAndNil(FBmp);
  FreeAndNil(FPic);
  FreeAndNil(FDiskPic);
  FreeAndNil(FFondos);
end;

{------------------------------------------------------------------------------
  BuscarRecursos: carpeta del .exe y hasta 6 niveles arriba; tambien entra
  (recursivo) a recursos / imagenes / iconos / fondos.
 ------------------------------------------------------------------------------}
function TFormVisor.BuscarRecursos: String;
const
  Probar: array[0..2] of String = ('pale.png', 'img1.png', 'f01.bmp');
  Subs: array[0..3] of String = ('recursos', 'imagenes', 'iconos', 'fondos');
var
  d, sub: String;
  i, j, k: Integer;
  L: TStringList;
begin
  Result := '';
  d := ExtractFilePath(ParamStr(0));
  for i := 0 to 6 do
  begin
    for k := 0 to High(Probar) do
      if FileExists(d + Probar[k]) then Exit(d);
    for j := 0 to High(Subs) do
    begin
      sub := Subs[j];
      if DirectoryExists(d + sub) then
      begin
        L := TStringList.Create;
        try
          FindAllFiles(L, d + sub, 'pale.png;img1.png;f01.bmp', True);
          if L.Count > 0 then Exit(d + sub + PathDelim);
        finally
          L.Free;
        end;
      end;
    end;
    if d = ExtractFilePath(ExcludeTrailingPathDelimiter(d)) then Break;
    d := ExtractFilePath(ExcludeTrailingPathDelimiter(d));
  end;
end;

{ Busca un archivo por nombre dentro de la carpeta de recursos (recursivo) }
function TFormVisor.BuscarArchivo(const ANombre: String): String;
var
  L: TStringList;
begin
  Result := '';
  L := TStringList.Create;
  try
    if FRec <> '' then
      FindAllFiles(L, FRec, ANombre, True);
    if L.Count = 0 then
      FindAllFiles(L, ExtractFilePath(ParamStr(0)), ANombre, False);
    if L.Count > 0 then
      Result := L[0];
  finally
    L.Free;
  end;
end;

{ Carga el primer icono existente de la lista en el Glyph del boton }
procedure TFormVisor.CargarGlyph(ABtn: TSpeedButton;
  const ANombres: array of String);
var
  i: Integer;
  f: String;
  Pic: TPicture;
begin
  for i := 0 to High(ANombres) do
  begin
    f := BuscarArchivo(ANombres[i]);
    if f = '' then Continue;
    Pic := TPicture.Create;
    try
      try
        Pic.LoadFromFile(f);
        ABtn.Glyph.Assign(Pic.Graphic);
        Exit;
      except
        // icono danado: probar el siguiente
      end;
    finally
      Pic.Free;
    end;
  end;
end;

{------------------------------------------------------------------------------
  CargarRecursosGraficos: fondos, iconos de botones, icono de ventana y logo
 ------------------------------------------------------------------------------}
procedure TFormVisor.CargarRecursosGraficos;
var
  f: String;
  bmpImg: TBitmap;
begin
  FRec := BuscarRecursos;

  // Fondos: img1..img6.png (Fondos.png es el collage y se excluye por el patron)
  if FRec <> '' then
    FindAllFiles(FFondos, FRec, 'img*.png;*.jpg;*.jpeg', True);
  if FFondos.Count = 0 then  // plan B: forest.png / mont.png junto al .exe
    FindAllFiles(FFondos, ExtractFilePath(ParamStr(0)), 'forest.png;mont.png', False);
  FFondos.Sort;

  if FFondos.Count = 0 then
    ShowMessage('No se encontraron imagenes de fondo.' + LineEnding +
      'Copie img1..img6.png, pale.png y los .bmp en una carpeta "recursos" ' +
      'junto al proyecto o junto al .exe.' + LineEnding +
      'Carpeta del exe: ' + ExtractFilePath(ParamStr(0)));

  // Iconos de los botones (f01 = camara, f02 = check On/off, pale = paleta)
  CargarGlyph(btnSave, ['camara.png', 'f01.bmp']);
  CargarGlyph(btnGridToggle, ['f02.bmp']);
  CargarGlyph(btnChangeBg, ['pale.png']);

  // Icono del formulario
  f := BuscarArchivo('f_003.bmp');
  if f <> '' then
  begin
    bmpImg := TBitmap.Create;
    try
      try
        bmpImg.LoadFromFile(f);
        Icon.Assign(bmpImg);
      except
      end;
    finally
      bmpImg.Free;
    end;
  end;

  // Logo del disquete AC (disk.png)
  f := BuscarArchivo('disk.png');
  if f <> '' then
  try
    FDiskPic.LoadFromFile(f);
  except
    FDiskPic.Clear;
  end;
end;

{------------------------------------------------------------------------------
  CargarFondo: carga la imagen FFondos[FIdx], descarta el cache y repinta
 ------------------------------------------------------------------------------}
procedure TFormVisor.CargarFondo;
begin
  FreeAndNil(FBmp);                  // se rehace con el nuevo fondo
  FPic.Clear;
  if (FFondos.Count > 0) and (FIdx >= 0) and (FIdx < FFondos.Count) then
  try
    FPic.LoadFromFile(FFondos[FIdx]);
  except
    FPic.Clear;
  end;
  ChartVisor.Invalidate;
end;

{------------------------------------------------------------------------------
  ChartVisorBackWall: dibuja el fondo "cubriendo" el area del grafico (sin
  deformar, centrado) y despues el logo AC. Usa el canvas del drawer, por lo
  que tambien sale correcto al guardar la captura.
 ------------------------------------------------------------------------------}
procedure TFormVisor.ChartVisorBackWall(ASender: TChart; ADrawer: IChartDrawer;
  const ARect: TRect; var ADoDefaultDrawing: Boolean);
var
  ic: IChartTCanvasDrawer;
  Cv: TCanvas;
  w, h, sw, sh, ox, oy: Integer;
  sc: Double;
begin
  if (FPic = nil) or (FPic.Graphic = nil) or FPic.Graphic.Empty then Exit;
  w := ARect.Right - ARect.Left;
  h := ARect.Bottom - ARect.Top;
  if (w < 4) or (h < 4) then Exit;

  if Supports(ADrawer, IChartTCanvasDrawer, ic) then
    Cv := ic.Canvas
  else
    Cv := ASender.Canvas;

  // Escalar solo cuando cambia el fondo o el tamano del area (cache en FBmp)
  if (FBmp = nil) or (FBmp.Width <> w) or (FBmp.Height <> h) then
  begin
    FBmp.Free;
    FBmp := TBitmap.Create;
    FBmp.SetSize(w, h);
    sc := Max(w / FPic.Width, h / FPic.Height);
    sw := Round(FPic.Width * sc);
    sh := Round(FPic.Height * sc);
    ox := (sw - w) div 2;
    oy := (sh - h) div 2;
    FBmp.Canvas.StretchDraw(Rect(-ox, -oy, sw - ox, sh - oy), FPic.Graphic);
  end;

  Cv.Draw(ARect.Left, ARect.Top, FBmp);

  // Logo del disquete AC en la esquina superior izquierda
  if (FDiskPic.Graphic <> nil) and (not FDiskPic.Graphic.Empty) then
    Cv.Draw(ARect.Left + 12, ARect.Top + 8, FDiskPic.Graphic);

  ADoDefaultDrawing := False;        // el chart no pinta la pared encima
end;

{ Compatibilidad con .lfm antiguos: no dibuja nada (el fondo se dibuja arriba) }
procedure TFormVisor.ChartVisorAfterDrawBackWall(ASender: TChart;
  ACanvas: TCanvas; const ARect: TRect);
begin
end;

{------------------------------------------------------------------------------
  ConfigurarBotones: eventos por codigo y botones que no quedan "pegados"
 ------------------------------------------------------------------------------}
procedure TFormVisor.ConfigurarBotones;
begin
  btnSave.GroupIndex := 0;
  btnGridToggle.GroupIndex := 0;
  btnChangeBg.GroupIndex := 0;
  btnSave.AllowAllUp := False;
  btnGridToggle.AllowAllUp := False;
  btnChangeBg.AllowAllUp := False;
  btnSave.Down := False;
  btnGridToggle.Down := False;
  btnChangeBg.Down := False;

  btnSave.OnClick := @btnSaveClick;
  btnGridToggle.OnClick := @btnGridToggleClick;
  btnChangeBg.OnClick := @btnChangeBgClick;
end;

{------------------------------------------------------------------------------
  InicializarGrafico: Configura propiedades requeridas del TChart y TLineSeries
 ------------------------------------------------------------------------------}
procedure TFormVisor.InicializarGrafico;
begin
  // Eje Y (Izquierdo): [ug/m3] de 0 a 200
  ChartVisor.LeftAxis.Title.Caption := '[ug/m3]';
  ChartVisor.LeftAxis.Title.Visible := True;
  ChartVisor.LeftAxis.Title.LabelFont.Style := [fsBold];
  ChartVisor.LeftAxis.Range.UseMin := True;
  ChartVisor.LeftAxis.Range.Min := 0;
  ChartVisor.LeftAxis.Range.UseMax := True;
  ChartVisor.LeftAxis.Range.Max := 200;
  ChartVisor.LeftAxis.Grid.Visible := False; // Inicia desactivada
  ChartVisor.LeftAxis.Grid.Color := clBlack;
  ChartVisor.LeftAxis.Grid.Style := psDot;

  // Eje X (Inferior): Sampling MP 2.5um de 0 a 29
  ChartVisor.BottomAxis.Title.Caption := 'Sampling MP 2.5um';
  ChartVisor.BottomAxis.Title.Visible := True;
  ChartVisor.BottomAxis.Title.LabelFont.Style := [fsBold];
  ChartVisor.BottomAxis.Range.UseMin := True;
  ChartVisor.BottomAxis.Range.Min := 0;
  ChartVisor.BottomAxis.Range.UseMax := True;
  ChartVisor.BottomAxis.Range.Max := TOTAL_MUESTRAS - 1;
  ChartVisor.BottomAxis.Grid.Visible := False; // Inicia desactivada
  ChartVisor.BottomAxis.Grid.Color := clBlack;
  ChartVisor.BottomAxis.Grid.Style := psDot;

  // Leyenda en la esquina superior derecha con borde
  ChartVisor.Legend.Visible := True;
  ChartVisor.Legend.Alignment := laTopRight;
  ChartVisor.Legend.UseSidebar := False;
  ChartVisor.Legend.Frame.Visible := True;
  ChartVisor.Legend.Frame.Color := clBlack;
  ChartVisor.Legend.BackgroundBrush.Color := clWhite;

  // Configuracion de la serie TLineSeries
  SerieMP25.Title := 'MP 2.5 um';
  SerieMP25.ShowPoints := True;
  SerieMP25.SeriesColor := clRed;
  SerieMP25.LinePen.Color := clRed;
  SerieMP25.LinePen.Width := 1;

  // Pointer: cuadrado azul con contorno amarillo
  SerieMP25.Pointer.Visible := True;
  SerieMP25.Pointer.Style := psRectangle;
  SerieMP25.Pointer.Brush.Color := clHighlight;
  SerieMP25.Pointer.Pen.Color := clYellow;
  SerieMP25.Pointer.Pen.Width := 1;
  SerieMP25.Pointer.HorizSize := 4;
  SerieMP25.Pointer.VertSize := 4;

  // Marks: caja blanca con borde negro mostrando valor
  SerieMP25.Marks.Visible := True;
  SerieMP25.Marks.Style := smsValue;
  SerieMP25.Marks.Format := '%0:.0f';
  SerieMP25.Marks.LabelBrush.Color := clWhite;
  SerieMP25.Marks.LabelBrush.Style := bsSolid;
  SerieMP25.Marks.Frame.Color := clBlack;
  SerieMP25.Marks.Frame.Visible := True;
  SerieMP25.Marks.Distance := 4;
  SerieMP25.Marks.Arrow.Visible := False;

  // Hints descriptivos en cada boton
  btnSave.Hint := 'Guardar captura de pantalla en captura.png';
  btnSave.ShowHint := True;
  btnGridToggle.Hint := 'Activar / Desactivar grilla del visor';
  btnGridToggle.ShowHint := True;
  btnChangeBg.Hint := 'Cambiar figura de fondo (background) del visor';
  btnChangeBg.ShowHint := True;

  FillChar(FMuestras, SizeOf(FMuestras), 0);
end;

{------------------------------------------------------------------------------
  IniciarComunicacionSerial: Configura y abre el puerto serial LazSerial en COM2
 ------------------------------------------------------------------------------}
procedure TFormVisor.IniciarComunicacionSerial;
begin
  try
    LazSerial1.Device := 'COM2';
    LazSerial1.BaudRate := br__9600;
    LazSerial1.DataBits := db8bits;
    LazSerial1.Parity := pNone;
    LazSerial1.StopBits := sbOne;
    LazSerial1.FlowControl := fcNone;
    LazSerial1.Open;
  except
    on E: Exception do
      tmrFallbackSim.Enabled := True;
  end;

  if not LazSerial1.Active then
    tmrFallbackSim.Enabled := True;
end;

{------------------------------------------------------------------------------
  btnGridToggleClick: Activa / Desactiva la grilla
 ------------------------------------------------------------------------------}
procedure TFormVisor.btnGridToggleClick(Sender: TObject);
var
  isGridOn: Boolean;
begin
  isGridOn := not ChartVisor.LeftAxis.Grid.Visible;
  ChartVisor.LeftAxis.Grid.Visible := isGridOn;
  ChartVisor.BottomAxis.Grid.Visible := isGridOn;
  ChartVisor.Invalidate;
end;

{------------------------------------------------------------------------------
  btnChangeBgClick: cambia al siguiente fondo (ciclico) y repinta
 ------------------------------------------------------------------------------}
procedure TFormVisor.btnChangeBgClick(Sender: TObject);
begin
  if FFondos.Count = 0 then
  begin
    ShowMessage('No hay imagenes de fondo cargadas.' + LineEnding +
      'Carpeta del exe: ' + ExtractFilePath(ParamStr(0)));
    Exit;
  end;
  FIdx := (FIdx + 1) mod FFondos.Count;
  CargarFondo;
end;

{------------------------------------------------------------------------------
  btnSaveClick: guarda captura de pantalla a captura.png
 ------------------------------------------------------------------------------}
procedure TFormVisor.btnSaveClick(Sender: TObject);
var
  Bmp: TBitmap;
  Png: TPortableNetworkGraphic;
  OutFile: String;
  p: TPoint;
begin
  OutFile := ExtractFilePath(ParamStr(0)) + 'captura.png';
  Bmp := TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    Bmp.SetSize(Self.ClientWidth, Self.ClientHeight);
    Self.PaintTo(Bmp.Canvas, 0, 0);

    // Repintar el grafico directamente sobre la captura (garantiza fondo y serie)
    p := ScreenToClient(ChartVisor.ClientToScreen(Point(0, 0)));
    ChartVisor.PaintOnCanvas(Bmp.Canvas,
      Rect(p.X, p.Y, p.X + ChartVisor.Width, p.Y + ChartVisor.Height));

    Png.Assign(Bmp);
    Png.SaveToFile(OutFile);
  finally
    Png.Free;
    Bmp.Free;
  end;
  ShowMessage('Captura realizada con exito' + LineEnding + OutFile);
end;

{------------------------------------------------------------------------------
  LazSerial1RxData: recibe datos del script de Python (9600 8N1)
 ------------------------------------------------------------------------------}
procedure TFormVisor.LazSerial1RxData(Sender: TObject);
var
  rawStr: AnsiString;
  pNL: Integer;
  linea: AnsiString;
  valNum: Double;
  fs: TFormatSettings;
begin
  rawStr := LazSerial1.ReadData;
  if rawStr = '' then Exit;

  FSerialBuffer := FSerialBuffer + rawStr;

  while True do
  begin
    pNL := Pos(#10, FSerialBuffer);
    if pNL <= 0 then Break;

    linea := Trim(Copy(FSerialBuffer, 1, pNL - 1));
    Delete(FSerialBuffer, 1, pNL);

    if linea <> '' then
    begin
      linea := StringReplace(linea, #13, '', [rfReplaceAll]);
      linea := StringReplace(linea, ',', '.', [rfReplaceAll]);
      fs := DefaultFormatSettings;
      fs.DecimalSeparator := '.';

      if TryStrToFloat(linea, valNum, fs) then
      begin
        // Desactivar simulacion de contingencia al recibir datos reales
        tmrFallbackSim.Enabled := False;
        AgregarMuestra(valNum);
      end;
    end;
  end;

  if Length(FSerialBuffer) > 4096 then
    FSerialBuffer := '';             // proteccion si llega basura
end;

{------------------------------------------------------------------------------
  tmrFallbackSimTimer: generador de contingencia N(80,5) si no hay puerto serial
 ------------------------------------------------------------------------------}
procedure TFormVisor.tmrFallbackSimTimer(Sender: TObject);
var
  u1, u2, z: Double;
  valNormal: Double;
begin
  u1 := Random;
  if u1 <= 0.00001 then u1 := 0.00001;
  u2 := Random;
  z := Sqrt(-2.0 * Ln(u1)) * Cos(2.0 * Pi * u2);
  valNormal := 80.0 + (5.0 * z);

  if valNormal < 0.0 then valNormal := 0.0;
  if valNormal > 200.0 then valNormal := 200.0;

  AgregarMuestra(Trunc(valNormal * 10.0) / 10.0);
end;

{------------------------------------------------------------------------------
  AgregarMuestra: ventana rodante de 30 muestras en TAChart
 ------------------------------------------------------------------------------}
procedure TFormVisor.AgregarMuestra(AValor: Double);
var
  i: Integer;
begin
  if AValor < 0.0 then AValor := 0.0;
  if AValor > 200.0 then AValor := 200.0;

  if FMuestrasCount < TOTAL_MUESTRAS then
  begin
    FMuestras[FMuestrasCount] := AValor;
    Inc(FMuestrasCount);
  end
  else
  begin
    for i := 0 to TOTAL_MUESTRAS - 2 do
      FMuestras[i] := FMuestras[i + 1];
    FMuestras[TOTAL_MUESTRAS - 1] := AValor;
  end;

  SerieMP25.BeginUpdate;
  try
    SerieMP25.Clear;
    for i := 0 to FMuestrasCount - 1 do
      SerieMP25.AddXY(i, FMuestras[i]);
  finally
    SerieMP25.EndUpdate;
  end;

  // Reenviar al Servidor Consola TCP/IP + SQLite (sin bloquear la interfaz)
  EnviarATcpServer(AValor);
end;

{------------------------------------------------------------------------------
  EnviarATcpServer: solo encola el mensaje; el hilo TEnvioTcp lo envia a
  127.0.0.1:5000
 ------------------------------------------------------------------------------}
procedure TFormVisor.EnviarATcpServer(AValor: Double);
var
  fs: TFormatSettings;
begin
  if FTcp = nil then Exit;
  fs := DefaultFormatSettings;
  fs.DecimalSeparator := '.';
  FTcp.Encolar(FloatToStr(AValor, fs) + #10);
end;

end.