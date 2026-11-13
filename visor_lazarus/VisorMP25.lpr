program VisorMP25;

{$mode objfpc}{$H+}

{==============================================================================
  PROYECTO #3 - INTERFACES GRÁFICAS (INFO1128)
  VISOR DE MATERIAL PARTICULADO MP 2.5 µm CON TCHART, TLAZSERIAL Y TCP/IP
  Autor: Kuro_Waza / INFO1128
  Docente: Alberto Caro | Ayudante: Daniela Romero
 ==============================================================================}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Interfaces, // LCL widgetset
  Forms, tachartlazaruspkg, LazSerialPort,
  main_unit;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFormVisor, FormVisor);
  Application.Run;
end.
