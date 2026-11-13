program ServerConsola;

{$mode objfpc}{$H+}
{$apptype console}

{==============================================================================
  PROYECTO #3 - INTERFACES GRÁFICAS (INFO1128)
  MÓDULO: SERVIDOR TCP/IP EN MODO CONSOLA CON ALMACENAMIENTO SQLITE (TABLA AIRE)
  Autor: Kuro_Waza / INFO1128
  Docente: Alberto Caro | Ayudante: Daniela Romero
 ==============================================================================
  Descripción:
    Este programa implementa un servidor TCP/IP en modo consola desarrollado
    en Lazarus Free Pascal. Escucha conexiones entrantes en el puerto 5000.
    Cada vez que la interfaz gráfica (Visor Lazarus) recibe un dato de MP 2.5
    desde el script Python, lo reenvía a este servidor mediante TCP/IP.
    
    El servidor:
      1. Imprime los datos recibidos por consola con fecha, hora y origen.
      2. Almacena cada registro de forma persistente en una base de datos
         SQLite3 denominada 'sensores.db', dentro de la tabla 'Aire'
         con los campos: id, fecha, hora y mp25.
      3. Permite la visualización y consulta concurrente en tiempo real
         mediante HeidiSQL.
 ==============================================================================}

uses
  SysUtils, Classes, DateUtils,
  sqlite3conn, sqldb, db,
  Windows, WinSock2;

const
  SERVER_PORT = 5000;
  DB_FILENAME = 'sensores.db';
  BUFFER_SIZE = 1024;

var
  Conn: TSQLite3Connection;
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  
  wsaData: TWSAData;
  serverSocket, clientSocket: TSocket;
  serverAddr, clientAddr: TSockAddrIn;
  clientAddrLen: Integer;
  
  buffer: array[0..BUFFER_SIZE - 1] of AnsiChar;
  bytesReceived: Integer;
  receivedStr: AnsiString;
  cleanValStr: AnsiString;
  mp25Val: Double;
  fechaStr, horaStr: AnsiString;
  ackMsg: AnsiString;
  clientIP: AnsiString;
  registroCount: Int64;

{------------------------------------------------------------------------------
  Inicializa la base de datos SQLite y crea la tabla 'Aire' si no existe.
 ------------------------------------------------------------------------------}
procedure InicializarBaseDeDatos;
begin
  WriteLn('[SQLITE] Conectando a la base de datos: ', DB_FILENAME);
  try
    Conn := TSQLite3Connection.Create(nil);
    Trans := TSQLTransaction.Create(nil);
    Query := TSQLQuery.Create(nil);

    Conn.DatabaseName := DB_FILENAME;
    Conn.Transaction := Trans;
    Query.DataBase := Conn;
    Query.Transaction := Trans;

    Conn.Open;
    Trans.Active := True;

    // Crear la tabla 'Aire' según requerimiento 12 del proyecto
    Query.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Aire (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      '  fecha TEXT NOT NULL, ' +
      '  hora TEXT NOT NULL, ' +
      '  mp25 REAL NOT NULL' +
      ');';
    Query.ExecSQL;
    Trans.Commit;

    WriteLn('[SQLITE] [OK] Tabla "Aire" verificada/creada exitosamente.');
  except
    on E: Exception do
    begin
      WriteLn('[SQLITE] [ERROR] Error al inicializar SQLite: ', E.Message);
      Halt(1);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Inserta un nuevo registro de MP 2.5 en la tabla 'Aire'.
 ------------------------------------------------------------------------------}
procedure GuardarLectura(const AFecha, AHora: AnsiString; const AValor: Double);
var
  FormatSettingsSafe: TFormatSettings;
begin
  try
    // Forzar punto decimal para consultas SQL en SQLite
    FormatSettingsSafe := DefaultFormatSettings;
    FormatSettingsSafe.DecimalSeparator := '.';

    if not Trans.Active then
      Trans.StartTransaction;

    Query.Close;
    Query.SQL.Text :=
      'INSERT INTO Aire (fecha, hora, mp25) VALUES (' +
      QuotedStr(AFecha) + ', ' +
      QuotedStr(AHora) + ', ' +
      FloatToStr(AValor, FormatSettingsSafe) + ');';
    Query.ExecSQL;
    Trans.Commit;
  except
    on E: Exception do
    begin
      WriteLn('[SQLITE] [ERROR] Falló inserción en tabla Aire: ', E.Message);
      Trans.Rollback;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Limpia y libera los recursos de la base de datos.
 ------------------------------------------------------------------------------}
procedure CerrarBaseDeDatos;
begin
  try
    if Assigned(Query) then Query.Free;
    if Assigned(Trans) then
    begin
      if Trans.Active then Trans.Commit;
      Trans.Free;
    end;
    if Assigned(Conn) then
    begin
      Conn.Close;
      Conn.Free;
    end;
    WriteLn('[SQLITE] Conexión cerrada correctamente.');
  except
    on E: Exception do
      WriteLn('[SQLITE] Error al cerrar conexión: ', E.Message);
  end;
end;

{------------------------------------------------------------------------------
  Programa Principal: Inicialización del Servidor TCP/IP y Loop de Eventos
 ------------------------------------------------------------------------------}
begin
  WriteLn('======================================================================');
  WriteLn('   SERVIDOR TCP/IP MODO CONSOLA + SQLITE (TABLA AIRE) - INFO1128      ');
  WriteLn('======================================================================');
  WriteLn(' Docente  : Alberto Caro | Ayudante: Daniela Romero                   ');
  WriteLn(' Proyecto : #3 Interfaces Gráficas - Visor Material Particulado MP2.5 ');
  WriteLn(' Puerto   : ', SERVER_PORT);
  WriteLn(' BD SQLite: ', DB_FILENAME, ' (Tabla: Aire)');
  WriteLn('======================================================================');
  WriteLn;

  registroCount := 0;

  // 1. Inicializar SQLite
  InicializarBaseDeDatos;

  // 2. Inicializar Winsock API
  if WSAStartup(MAKEWORD(2, 2), wsaData) <> 0 then
  begin
    WriteLn('[TCP] [ERROR] No se pudo inicializar Winsock.');
    CerrarBaseDeDatos;
    Halt(1);
  end;

  // 3. Crear socket de escucha
  serverSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if serverSocket = INVALID_SOCKET then
  begin
    WriteLn('[TCP] [ERROR] No se pudo crear el socket del servidor.');
    WSACleanup();
    CerrarBaseDeDatos;
    Halt(1);
  end;

  // 4. Vincular el socket a la dirección y puerto local
  FillChar(serverAddr, SizeOf(serverAddr), 0);
  serverAddr.sin_family := AF_INET;
  serverAddr.sin_port := htons(SERVER_PORT);
  serverAddr.sin_addr.s_addr := INADDR_ANY;

  if bind(serverSocket, @serverAddr, SizeOf(serverAddr)) = SOCKET_ERROR then
  begin
    WriteLn('[TCP] [ERROR] No se pudo enlazar el socket al puerto ', SERVER_PORT);
    closesocket(serverSocket);
    WSACleanup();
    CerrarBaseDeDatos;
    Halt(1);
  end;

  // 5. Poner el socket en modo escucha (Listen)
  if listen(serverSocket, SOMAXCONN) = SOCKET_ERROR then
  begin
    WriteLn('[TCP] [ERROR] Error al poner el socket en modo escucha.');
    closesocket(serverSocket);
    WSACleanup();
    CerrarBaseDeDatos;
    Halt(1);
  end;

  WriteLn('[TCP] Servidor a la escucha en el puerto ', SERVER_PORT, '...');
  WriteLn('[TCP] Esperando conexiones de la interfaz Visor Lazarus (Ctrl+C para salir).');
  WriteLn('----------------------------------------------------------------------');

  // 6. Bucle de recepción de datos
  while True do
  begin
    clientAddrLen := SizeOf(clientAddr);
    clientSocket := accept(serverSocket, @clientAddr, @clientAddrLen);

    if clientSocket <> INVALID_SOCKET then
    begin
      clientIP := AnsiString(inet_ntoa(clientAddr.sin_addr));
      
      // Leer el mensaje enviado por el cliente
      FillChar(buffer, SizeOf(buffer), 0);
      bytesReceived := recv(clientSocket, buffer, BUFFER_SIZE - 1, 0);

      if bytesReceived > 0 then
      begin
        buffer[bytesReceived] := #0;
        receivedStr := Trim(AnsiString(buffer));

        // Si la trama viene con prefijo como "MP25:82.4", extraer sólo el número
        cleanValStr := receivedStr;
        if Pos(':', cleanValStr) > 0 then
          cleanValStr := Trim(Copy(cleanValStr, Pos(':', cleanValStr) + 1, Length(cleanValStr)));

        // Reemplazar coma por punto si fuera necesario
        cleanValStr := StringReplace(cleanValStr, ',', '.', [rfReplaceAll]);

        // Parsear valor numérico de MP 2.5
        FormatSettings.DecimalSeparator := '.';
        if TryStrToFloat(cleanValStr, mp25Val) then
        begin
          Inc(registroCount);
          fechaStr := FormatDateTime('yyyy-mm-dd', Now);
          horaStr  := FormatDateTime('hh:nn:ss', Now);

          // Requerimiento 12: "Los datos recibidos se deben mostrar también por consola"
          WriteLn(Format('[%05d] %s %s | Cliente: %s | MP 2.5: %6.1f ug/m3 -> Guardado en SQLite',
            [registroCount, fechaStr, horaStr, clientIP, mp25Val]));

          // Requerimiento 12: "almacene los datos en SQLITE Tabla Aire con Fecha y Hora"
          GuardarLectura(fechaStr, horaStr, mp25Val);

          // Responder confirmación ACK al cliente
          ackMsg := 'ACK_OK' + #10;
          send(clientSocket, PAnsiChar(ackMsg), Length(ackMsg), 0);
        end
        else
        begin
          WriteLn('[ADVERTENCIA] Dato recibido no numérico: "', receivedStr, '" desde ', clientIP);
        end;
      end;

      // Cerrar la conexión con este cliente (modelo transaccional rápido)
      closesocket(clientSocket);
    end;
  end;

  // Limpieza final
  closesocket(serverSocket);
  WSACleanup();
  CerrarBaseDeDatos;
end.
