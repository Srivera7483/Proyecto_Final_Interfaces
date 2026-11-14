unit main_unit;

{$mode objfpc}{$H+}

{==============================================================================
  PROYECTO #3 - INTERFACES GRÁFICAS (INFO1128)
  UNIDAD: main_unit.pas - VISOR DE MATERIAL PARTICULADO MP 2.5 µm
  Autor: Kuro_Waza / INFO1128
  Docente: Alberto Caro | Ayudante: Daniela Romero
 ==============================================================================
  Descripción:
    Esta unidad contiene la interfaz gráfica de usuario completa exigida en
    el Proyecto #3:
      1. TChart con TLineSeries para 30 muestras continuas (rango 0 a 29).
      2. Configuración estética completa: Legend, LinePen, Marks, Frame,
         LabelBrush, Style, Pointer, SeriesColor.
      3. Renderizado de fondos panorámicos e icono floppy AC (disk.png)
         en el evento OnBeforeDrawBackWall.
      4. Botón 'Save' (icono camara.png) para exportar captura a 'captura.png'.
      5. Botón 'On/off' (iconos de toggle f01.bmp/f02.bmp) para alternar grilla.
      6. Botón 'Click' (icono pale.png) para alternar figuras de fondo.
      7. Componente TLazSerial configurado a 9600 Bps, 8N1 en COM2.
      8. Cliente TCP/IP para enviar las muestras recibidas al Server Consola
         en 127.0.0.1:5000.
      9. Hints descriptivos activados en todos los botones y controles.
 ==============================================================================}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  ExtCtrls, TAGraph, TASeries, TALegend, TACustomSeries, TATypes,
  TAChartAxisUtils, TAChartUtils, LazSerial;

const
  TOTAL_MUESTRAS = 30; // Ventana rodante de 30 muestras (0 .. 29)
  TCP_SERVER_IP = '127.0.0.1';
  TCP_SERVER_PORT = 5000;

type

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
    procedure ChartVisorAfterDrawBackWall(ASender: TChart; const ARect: TRect);
    procedure LazSerial1RxData(Sender: TObject);
    procedure tmrFallbackSimTimer(Sender: TObject);

  private
    { Imágenes y recursos gráficos }
    FBackgrounds: array of Graphics.TGraphic;
    FCurrentBgIndex: Integer;
    FDiskBmp: Graphics.TGraphic;
    FGlyphOn: Graphics.TBitmap;
    FGlyphOff: Graphics.TBitmap;

    { Variables para serie temporal }
    FSerialBuffer: AnsiString;
    FMuestras: array[0..TOTAL_MUESTRAS - 1] of Double;
    FMuestrasCount: Integer;

    { Métodos internos }
    procedure CargarRecursosGraficos;
    procedure InicializarGrafico;
    procedure AgregarMuestra(AValor: Double);
    procedure EnviarATcpServer(AValor: Double);
    procedure IniciarComunicacionSerial;

  public

  end;

var
  FormVisor: TFormVisor;

implementation

uses
  Windows, WinSock2;

{$R *.lfm}

{------------------------------------------------------------------------------
  FormCreate: Inicialización de la ventana, carga de recursos y configuración
 ------------------------------------------------------------------------------}
procedure TFormVisor.FormCreate(Sender: TObject);
begin
  Caption := 'By Alberto Caro';
  DoubleBuffered := True;
  FMuestrasCount := 0;
  FSerialBuffer := '';
  FCurrentBgIndex := 0;

  // 1. Cargar imágenes desde el directorio del ejecutable
  CargarRecursosGraficos;

  // 2. Configurar TAChart, serie, ejes y leyendas
  InicializarGrafico;

  // 3. Iniciar componente serial TLazSerial (COM2, 9600-8N1)
  IniciarComunicacionSerial;
end;

{------------------------------------------------------------------------------
  FormDestroy: Liberación segura de recursos de memoria y puerto serial
 ------------------------------------------------------------------------------}
procedure TFormVisor.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  try
    if LazSerial1.Active then
      LazSerial1.Close;
  except
  end;

  for i := 0 to High(FBackgrounds) do
    if Assigned(FBackgrounds[i]) then
      FBackgrounds[i].Free;
  SetLength(FBackgrounds, 0);

  if Assigned(FDiskBmp) then FDiskBmp.Free;
  if Assigned(FGlyphOn) then FGlyphOn.Free;
  if Assigned(FGlyphOff) then FGlyphOff.Free;
end;

{------------------------------------------------------------------------------
  CargarRecursosGraficos: Carga glifos, fondos y logos desde archivos locales
 ------------------------------------------------------------------------------}
procedure TFormVisor.CargarRecursosGraficos;
var
  resPath, fname: String;
  bgNames: array[0..5] of String;
  i: Integer;
  pngImg: TPortableNetworkGraphic;
  bmpImg: Graphics.TBitmap;
begin
  resPath := ExtractFilePath(Application.ExeName);

  // Icono del formulario (f_003.bmp)
  fname := resPath + 'f_003.bmp';
  if FileExists(fname) then
  begin
    bmpImg := Graphics.TBitmap.Create;
    try
      bmpImg.LoadFromFile(fname);
      Icon.Assign(bmpImg);
    finally
      bmpImg.Free;
    end;
  end;

  // Glifos para botón On/off (f01.bmp y f02.bmp)
  FGlyphOn := Graphics.TBitmap.Create;
  FGlyphOff := Graphics.TBitmap.Create;
  if FileExists(resPath + 'f01.bmp') then
    FGlyphOn.LoadFromFile(resPath + 'f01.bmp');
  if FileExists(resPath + 'f02.bmp') then
    FGlyphOff.LoadFromFile(resPath + 'f02.bmp');

  if FGlyphOn.Width > 0 then
    btnGridToggle.Glyph.Assign(FGlyphOn);

  // Icono de la cámara fotográfica para botón 'Save' (camara.png)
  fname := resPath + 'camara.png';
  if FileExists(fname) then
  begin
    pngImg := TPortableNetworkGraphic.Create;
    try
      pngImg.LoadFromFile(fname);
      btnSave.Glyph.Assign(pngImg);
    finally
      pngImg.Free;
    end;
  end;

  // Icono de la paleta de colores para botón 'Click' (pale.png)
  fname := resPath + 'pale.png';
  if FileExists(fname) then
  begin
    pngImg := TPortableNetworkGraphic.Create;
    try
      pngImg.LoadFromFile(fname);
      btnChangeBg.Glyph.Assign(pngImg);
    finally
      pngImg.Free;
    end;
  end;

  // Icono del disquete (disk.png) - marca de agua AC
  fname := resPath + 'disk.png';
  if FileExists(fname) then
  begin
    pngImg := TPortableNetworkGraphic.Create;
    pngImg.LoadFromFile(fname);
    FDiskBmp := pngImg;
  end
  else
    FDiskBmp := nil;

  // Fondos panorámicos del visor (img1 .. img6)
  bgNames[0] := 'img1.png';
  bgNames[1] := 'img2.png';
  bgNames[2] := 'img3.png';
  bgNames[3] := 'img4.png';
  bgNames[4] := 'img5.png';
  bgNames[5] := 'img6.png';

  SetLength(FBackgrounds, 6);
  for i := 0 to 5 do
  begin
    fname := resPath + bgNames[i];
    if FileExists(fname) then
    begin
      pngImg := TPortableNetworkGraphic.Create;
      pngImg.LoadFromFile(fname);
      FBackgrounds[i] := pngImg;
    end
    else
      FBackgrounds[i] := nil;
  end;
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
  ChartVisor.LeftAxis.Grid.Visible := False; // Inicia desactivada (Punto 7)
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
  ChartVisor.BottomAxis.Grid.Visible := False; // Inicia desactivada (Punto 7)
  ChartVisor.BottomAxis.Grid.Color := clBlack;
  ChartVisor.BottomAxis.Grid.Style := psDot;

  // Leyenda en la esquina superior derecha con borde
  ChartVisor.Legend.Visible := True;
  ChartVisor.Legend.Alignment := laTopRight;
  ChartVisor.Legend.UseSidebar := False;
  ChartVisor.Legend.Frame.Visible := True;
  ChartVisor.Legend.Frame.Color := clBlack;
  ChartVisor.Legend.BackgroundBrush.Color := clWhite;

  // Configuración de la serie TLineSeries (Puntos 10 y 11)
  SerieMP25.Title := 'MP 2.5 um';
  SerieMP25.ShowPoints := True;
  SerieMP25.SeriesColor := clRed;
  SerieMP25.LinePen.Color := clRed;
  SerieMP25.LinePen.Width := 1;

  // Pointer: Cuadrado azul con contorno amarillo (Pointer)
  SerieMP25.Pointer.Visible := True;
  SerieMP25.Pointer.Style := psRectangle;
  SerieMP25.Pointer.Brush.Color := clHighlight; // Azul
  SerieMP25.Pointer.Pen.Color := clYellow;      // Amarillo
  SerieMP25.Pointer.Pen.Width := 1;
  SerieMP25.Pointer.HorizSize := 4;
  SerieMP25.Pointer.VertSize := 4;

  // Marks: Caja blanca con borde negro mostrando valor (Marks, Frame, LabelBrush)
  SerieMP25.Marks.Visible := True;
  SerieMP25.Marks.Style := smsValue;
  SerieMP25.Marks.Format := '%0:.0f';
  SerieMP25.Marks.LabelBrush.Color := clWhite;
  SerieMP25.Marks.LabelBrush.Style := bsSolid;
  SerieMP25.Marks.Frame.Color := clBlack;
  SerieMP25.Marks.Frame.Visible := True;
  SerieMP25.Marks.Distance := 4;
  SerieMP25.Marks.Arrow.Visible := False;

  // Hints descriptivos en cada botón (Punto 9)
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
  ChartVisorBeforeDrawBackWall: Dibuja el fondo dinámico y el logo del disquete
 ------------------------------------------------------------------------------}
procedure TFormVisor.ChartVisorAfterDrawBackWall(ASender: TChart; const ARect: TRect);
begin
  // Dibujar el fondo seleccionado actualmente
  if (Length(FBackgrounds) > 0) and Assigned(FBackgrounds[FCurrentBgIndex]) then
  begin
    ASender.Canvas.StretchDraw(ARect, FBackgrounds[FCurrentBgIndex]);
  end;

  // Dibujar el logo del disquete (AC) en la esquina superior izquierda
  if Assigned(FDiskBmp) then
  begin
    ASender.Canvas.Draw(ARect.Left + 12, ARect.Top + 8, FDiskBmp);
  end;
end;

{------------------------------------------------------------------------------
  btnGridToggleClick: Requerimiento 7 -> Activa / Desactiva la grilla
 ------------------------------------------------------------------------------}
procedure TFormVisor.btnGridToggleClick(Sender: TObject);
var
  isGridOn: Boolean;
begin
  isGridOn := not ChartVisor.LeftAxis.Grid.Visible;

  ChartVisor.LeftAxis.Grid.Visible := isGridOn;
  ChartVisor.BottomAxis.Grid.Visible := isGridOn;

  if isGridOn then
  begin
    if FGlyphOn.Width > 0 then
      btnGridToggle.Glyph.Assign(FGlyphOn);
  end
  else
  begin
    if FGlyphOff.Width > 0 then
      btnGridToggle.Glyph.Assign(FGlyphOff);
  end;

  ChartVisor.Invalidate;
end;

{------------------------------------------------------------------------------
  btnChangeBgClick: Requerimiento 8 -> Cambia secuencialmente la imagen de fondo
 ------------------------------------------------------------------------------}
procedure TFormVisor.btnChangeBgClick(Sender: TObject);
begin
  if Length(FBackgrounds) > 0 then
  begin
    FCurrentBgIndex := (FCurrentBgIndex + 1) mod Length(FBackgrounds);
    ChartVisor.Invalidate;
  end;
end;

{------------------------------------------------------------------------------
  btnSaveClick: Requerimiento 6 -> Guarda captura de pantalla a captura.png
 ------------------------------------------------------------------------------}
procedure TFormVisor.btnSaveClick(Sender: TObject);
var
  Bmp: Graphics.TBitmap;
  Png: TPortableNetworkGraphic;
  OutFile: String;
begin
  Bmp := Graphics.TBitmap.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    Bmp.SetSize(Self.ClientWidth, Self.ClientHeight);
    Self.PaintTo(Bmp.Canvas, 0, 0);

    Png.Assign(Bmp);
    OutFile := ExtractFilePath(Application.ExeName) + 'captura.png';
    Png.SaveToFile(OutFile);

    ShowMessage('Captura realizada con éxito:' + LineEnding + OutFile);
  finally
    Png.Free;
    Bmp.Free;
  end;
end;

{------------------------------------------------------------------------------
  LazSerial1RxData: Requerimiento 4 -> Recibe datos del script de Python
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
        // Desactivar simulación de contingencia al recibir datos reales
        tmrFallbackSim.Enabled := False;
        AgregarMuestra(valNum);
      end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  tmrFallbackSimTimer: Generador de contingencia N(80,5) si no hay puerto serial
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
  AgregarMuestra: Mantiene la ventana rodante de 30 muestras en TAChart
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

  // Requerimiento 12: Reenviar al Servidor Consola TCP/IP + SQLite
  EnviarATcpServer(AValor);
end;

{------------------------------------------------------------------------------
  EnviarATcpServer: Requerimiento 12 -> Envío TCP/IP a 127.0.0.1:5000
 ------------------------------------------------------------------------------}
procedure TFormVisor.EnviarATcpServer(AValor: Double);
var
  wsaData: TWSAData;
  sock: TSocket;
  serverAddr: TSockAddrIn;
  msg: AnsiString;
  fs: TFormatSettings;
begin
  if WSAStartup(MAKEWORD(2, 2), wsaData) <> 0 then Exit;

  sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if sock = INVALID_SOCKET then
  begin
    WSACleanup();
    Exit;
  end;

  FillChar(serverAddr, SizeOf(serverAddr), 0);
  serverAddr.sin_family := AF_INET;
  serverAddr.sin_port := htons(TCP_SERVER_PORT);
  serverAddr.sin_addr.s_addr := inet_addr(PAnsiChar(AnsiString(TCP_SERVER_IP)));

  if connect(sock, @serverAddr, SizeOf(serverAddr)) = 0 then
  begin
    fs := DefaultFormatSettings;
    fs.DecimalSeparator := '.';
    msg := FloatToStr(AValor, fs) + #10;
    send(sock, PAnsiChar(msg), Length(msg), 0);
  end;

  closesocket(sock);
  WSACleanup();
end;

end.



