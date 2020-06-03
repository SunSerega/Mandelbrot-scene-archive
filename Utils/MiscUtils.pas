﻿unit MiscUtils;
{$string_nullbased+}

uses System.Diagnostics;
uses System.Threading;
uses System.Threading.Tasks;

{$region Misc}

type
  StrConsts = static class
    const OutputPipeId    = 'OutputPipeId';
  end;
  
var pack_timer := Stopwatch.StartNew;
var sec_procs := new List<Process>;
var sec_thrs := new List<Thread>;
var in_err_state := false;
var in_err_state_lock := new object;
var nfi := new System.Globalization.NumberFormatInfo;
var enc := new System.Text.UTF8Encoding(true);
var is_secondary_proc: boolean;

function TimeToStr(self: int64): string; extensionmethod :=
(self/10/1000/1000).ToString('N7', nfi).PadLeft(11);

procedure RegisterThr;
begin
  var thr := Thread.CurrentThread;
  
  lock sec_thrs do sec_thrs += thr;
  if in_err_state then thr.Abort;
  
end;

function GetFullPath(fname: string; base_folder: string := System.Environment.CurrentDirectory): string;
begin
  if System.IO.Path.IsPathRooted(fname) then
  begin
    Result := fname;
    exit;
  end;
  
  var path := GetFullPath(base_folder);
  if path.EndsWith('\') then path := path.Remove(path.Length-1);
  
  while fname.StartsWith('..\') do
  begin
    fname := fname.Substring(3);
    path := System.IO.Path.GetDirectoryName(path);
  end;
  if fname.StartsWith('\') then fname := fname.Substring(1);
  
  Result := $'{path}\{fname}';
end;
function GetFullPathRTE(fname: string) := GetFullPath(fname, System.IO.Path.GetDirectoryName(GetEXEFileName));

function GetRelativePath(fname: string; base_folder: string := System.Environment.CurrentDirectory): string;
begin
  fname := GetFullPath(fname);
  base_folder := GetFullPath(base_folder);
  
  var ind := 0;
  while true do
  begin
    if ind=fname.Length then break;
    if ind=base_folder.Length then break;
    if fname[ind]<>base_folder[ind] then break;
    ind += 1;
  end;
  
  if ind=0 then
  begin
    Result := fname;
    exit;
  end;
  
  var res := new StringBuilder;
  
  if ind <> base_folder.Length then
    loop base_folder.Skip(ind).Count(ch->ch='\') + 1 do
      res += '..\';
  
  if ind <> fname.Length then
  begin
    if fname[ind]='\' then ind += 1;
    res.Append(fname, ind, fname.Length-ind);
  end;
  
  Result := res.ToString;
end;

{$endregion Misc}

{$region Exception's}

type
  MessageException = class(Exception)
    constructor(text: string) :=
    inherited Create(text);
  end;
  
{$endregion Exception's}

{$region Timer's}

type
  ExeTimer = class;
  Timer = abstract class
    private static main: ExeTimer;
    
    protected total_time: int64;
    
    public function MeasureTime<T>(f: ()->T): T;
    begin
      var sw := Stopwatch.StartNew;
      try
        Result := f();
      finally
        sw.Stop;
        total_time += sw.ElapsedTicks;
      end;
    end;
    public procedure MeasureTime(p: ()->());
    begin
      var sw := Stopwatch.StartNew;
      try
        p();
      finally
        sw.Stop;
        total_time += sw.ElapsedTicks;
      end;
    end;
    
    private static TextLogLvlColors := Arr(System.ConsoleColor.Black, System.ConsoleColor.DarkGray);
    protected static property TextLogColor[lvl: integer]: System.ConsoleColor read TextLogLvlColors[lvl mod TextLogLvlColors.Length];
    protected procedure TextLog(lvl: integer; header: string; otp: (integer, string)->()); abstract;
    
    public static procedure TextLogAll(otp: (integer, string)->());
    
    public procedure Save(bw: System.IO.BinaryWriter); abstract;
    public procedure MergeLoad(br: System.IO.BinaryReader); abstract;
    
  end;
  
  SimpleTimer = sealed class(Timer)
    
    protected procedure TextLog(lvl: integer; header: string; otp: (integer, string)->()); override :=
    otp(lvl, $'{header} : {total_time.TimeToStr}');
    
    public procedure Save(bw: System.IO.BinaryWriter); override :=
    bw.Write(self.total_time);
    public procedure MergeLoad(br: System.IO.BinaryReader); override :=
    lock self do total_time += br.ReadInt64;
    
  end;
  
  ContainerTimer<TTimer> = sealed class(Timer) where TTimer: Timer, constructor;
    
    private sub_timers := new Dictionary<string, TTimer>;
    private function GetSubTimer(name: string): TTimer;
    begin
      lock sub_timers do
        if not sub_timers.TryGetValue(name, Result) then
        begin
          Result := new TTimer;
          sub_timers[name] := Result;
        end;
    end;
    property SubTimer[name: string]: TTimer read GetSubTimer; default;
    property SubTimerNames: sequence of string read sub_timers.Keys;
    property Empty: boolean read sub_timers.Count=0;
    
    protected procedure TextLog(lvl: integer; header: string; otp: (integer, string)->()); override;
    begin
      if Empty then exit;
      
      total_time := 0;
      foreach var t in sub_timers.Values do
      begin
        var tt := t as Timer; //ToDo #2247
        total_time += tt.total_time;
      end;
      
      otp(lvl, $'{header} : {total_time.TimeToStr}');
      
      var max_name_len := sub_timers.Keys.Max(name->name.Length);
      foreach var name in sub_timers.Keys do
        sub_timers[name].TextLog(lvl+1, $'• {name.PadRight(max_name_len)}', otp);
      
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(sub_timers.Count);
      foreach var name in sub_timers.Keys do
      begin
        bw.Write(name);
        sub_timers[name].Save(bw);
      end;
    end;
    public procedure MergeLoad(br: System.IO.BinaryReader); override :=
    lock self do
      loop br.ReadInt32 do
        SubTimer[br.ReadString].MergeLoad(br);
    
  end;
  
  ExeTimer = sealed class(Timer)
    public pas_comp := new ContainerTimer<SimpleTimer>;
    public exe_exec := new ContainerTimer<ExeTimer>;
    
    private const total_str     = 'Total';
    private const pas_comp_str  = '.pas compilation';
    private const exe_exec_str  = '.exe execution';
    
    protected procedure TextLog(lvl: integer; header: string; otp: (integer, string)->()); override;
    begin
      if header=nil then header := total_str;
      
      otp(lvl, $'{header} : {total_time.TimeToStr}');
      
      var header_lens := new List<integer>;
      if not pas_comp.Empty then header_lens += pas_comp_str.Length;
      if not exe_exec.Empty then header_lens += exe_exec_str.Length;
      if header_lens.Count=0 then exit;
      var max_header_len := header_lens.Max;
      
      if not pas_comp.Empty then pas_comp.TextLog(lvl+1, pas_comp_str.PadRight(max_header_len), otp);
      if not exe_exec.Empty then exe_exec.TextLog(lvl+1, exe_exec_str.PadRight(max_header_len), otp);
      
    end;
    
    public procedure Save(bw: System.IO.BinaryWriter); override;
    begin
      bw.Write(total_time);
      pas_comp.Save(bw);
      exe_exec.Save(bw);
    end;
    public procedure MergeLoad(br: System.IO.BinaryReader); override :=
    lock self do
    begin
      total_time += br.ReadInt64; // 0 для рута, поэтому не важно
      pas_comp.MergeLoad(br);
      exe_exec.MergeLoad(br);
    end;
    
  end;
  
static procedure Timer.TextLogAll(otp: (integer, string)->());
begin
  main.total_time := pack_timer.ElapsedTicks;
  main.TextLog(0, nil, otp);
end;

{$endregion Timer's}

{$region Otp type's}

type
  OtpLine = sealed class
    s: string;
    t: int64;
    bg_colors := System.Linq.Enumerable.Empty&<(integer,System.ConsoleColor)>;
    
    constructor(s: string; t: int64);
    begin
      self.s := s;
      self.t := t;
    end;
    constructor(s: string) := Create(s, pack_timer.ElapsedTicks);
    constructor(s: string; bg_colors: sequence of (integer,System.ConsoleColor));
    begin
      Create(s);
      self.bg_colors := bg_colors;
    end;
    
    static function operator implicit(s: string): OtpLine := new OtpLine(s);
    
    function ConvStr(f: string->string) := new OtpLine(f(self.s), self.t);
    
    function GetTimedStr :=
    $'{t.TimeToStr} | {s}';
    
    procedure Print;
    begin
      var i := 0;
      foreach var t in bg_colors do
      begin
        Console.BackgroundColor := t[1];
        Console.Write( s.Substring(i,t[0]) );
        i += t[0];
      end;
      Console.BackgroundColor := System.ConsoleColor.Black;
      Console.WriteLine( s.Substring(i) );
    end;
    
  end;
  
  ThrProcOtp = sealed class
    q := new Queue<OtpLine>;
    done := false;
    ev := new ManualResetEvent(false);
    
    [System.ThreadStatic] static curr: ThrProcOtp;
    
    procedure Enq(l: OtpLine) :=
    lock q do
    begin
      q.Enqueue(l);
      ev.Set;
    end;
    
    procedure EnqSub(o: ThrProcOtp) :=
    foreach var l in o.Enmr do Enq(l);
    
    procedure Finish;
    begin
      lock q do
      begin
        if done then exit;
        done := true;
        ev.Set;
      end;
    end;
    
    function Deq: OtpLine;
    begin
      Result := nil;
      
      lock q do
        if q.Count=0 then
        begin
          if done then
          begin
            exit;
          end else
            ev.Reset;
        end else
        begin
          Result := q.Dequeue;
          exit;
        end;
      
      ev.WaitOne;
      lock q do Result := (q.Count=0) and done ? nil : q.Dequeue;
    end;
    
    function Enmr: sequence of OtpLine;
    begin
      while true do
      begin
        var l := Deq;
        if l=nil then exit;
        yield l;
      end;
    end;
    
  end;
  
{$endregion Otp type's}

{$region Logging type's}

type
  Logger = abstract class
    public static main_log: Logger;
    
    private sub_loggers := new List<Logger>;
    
    protected static files_only_timed := false;
    
    public static procedure operator+=(log1, log2: Logger) :=
    log1.sub_loggers += log2;
    public static function operator+(log1, log2: Logger): Logger;
    begin
      log1 += log2;
      Result := log1;
    end;
    
    public procedure Otp(l: OtpLine); virtual;
    begin
      
      OtpImpl(l);
      
      foreach var log in sub_loggers do
        log.Otp(l);
    end;
    protected procedure OtpImpl(l: OtpLine); abstract;
    
    public procedure Close; virtual :=
    foreach var log in sub_loggers do
      log.Close;
    
  end;
  
  ConsoleLogger = sealed class(Logger)
    
    private constructor := exit;
    
    public procedure OtpImpl(l: OtpLine); override;
    begin
      if l.s.ToLower.Contains('error') then     Console.ForegroundColor := System.ConsoleColor.Red else
      if l.s.ToLower.Contains('fatal') then     Console.ForegroundColor := System.ConsoleColor.Red else
      if l.s.ToLower.Contains('exception') then Console.ForegroundColor := System.ConsoleColor.Red else
      if l.s.ToLower.Contains('warning') then   Console.ForegroundColor := System.ConsoleColor.Yellow else
        Console.ForegroundColor := System.ConsoleColor.DarkGreen;
      
      l.Print;
      
      Console.ForegroundColor := System.ConsoleColor.DarkGreen;
    end;
    
    public procedure Close; override;
    begin
      files_only_timed := true;
      
      self.Otp('');
      Timer.TextLogAll((lvl, s)->self.Otp(new OtpLine(' '*(lvl*4) + s, SeqGen(lvl, i->(i=0?3:4,Timer.TextLogColor[i])))));
      
      inherited;
    end;
    
  end;
  
  ParentStreamLogger = sealed class(Logger)
    private bw: System.IO.BinaryWriter;
    
    private constructor;
    begin
      var str := new System.IO.Pipes.AnonymousPipeClientStream(
        System.IO.Pipes.PipeDirection.Out,
        CommandLineArgs
        .First(arg->arg.StartsWith(StrConsts.OutputPipeId))
        .Substring(StrConsts.OutputPipeId.Length+1)
      );
      self.bw := new System.IO.BinaryWriter(str);
      bw.Write(byte(0)); // подтверждение соединения для другой стороны (так проще ошибку ловить)
    end;
    
    protected procedure OtpImpl(l: OtpLine); override;
    begin
      bw.Write(1);
      bw.Write(l.t);
      bw.Write(l.s);
      bw.Flush;
    end;
    
    public procedure Close; override;
    begin
      
      bw.Write(2);
      Timer.main.Save(bw);
      bw.Close;
      
      inherited;
    end;
    
  end;
  
  FileLogger = sealed class(Logger)
    private bu_fname: string;
    private main_sw: System.IO.StreamWriter;
    private backup_sw: System.IO.StreamWriter;
    private timed: boolean;
    
    public constructor(fname: string; timed: boolean := false);
    begin
      self.bu_fname   := fname+'.backup';
      self.main_sw    := new System.IO.StreamWriter(fname, false, enc);
      self.backup_sw  := new System.IO.StreamWriter(bu_fname, false, enc);
      self.timed      := timed;
    end;
    
    public procedure OtpImpl(l: OtpLine); override;
    begin
      if files_only_timed and not timed then exit;
      var s := timed ? l.GetTimedStr : l.s;
      
      main_sw.WriteLine(s);
      main_sw.Flush;
      
      backup_sw.WriteLine(s);
      backup_sw.Flush;
      
    end;
    
    public procedure Close; override;
    begin
      
      main_sw.Close;
      backup_sw.Close;
      System.IO.File.Delete(bu_fname);
      
      inherited;
    end;
    
  end;
  
{$endregion Logging type's}

{$region Otp}

procedure Otp(line: OtpLine) :=
if ThrProcOtp.curr<>nil then
  ThrProcOtp.curr.Enq(line) else
lock Logger.main_log do
  Logger.main_log.Otp(line);

/// Остановка других потоков и подпроцессов, довывод асинхронного вывода и вывод ошибки
/// На случай ThreadAbortException - после вызова ErrOtp в потоке больше ничего быть не должно
procedure ErrOtp(e: Exception);
begin
  if e is ThreadAbortException then
    if is_secondary_proc then exit else
    begin
      Readln;
      Halt;
    end;
  
  lock in_err_state_lock do
  begin
    if in_err_state then exit;
    in_err_state := true;
  end;
  
  lock sec_thrs do
    foreach var thr in sec_thrs do
      if thr<>Thread.CurrentThread then
        thr.Abort;
  
  lock sec_procs do
    foreach var p in sec_procs do
      try
        p.Kill;
      except end;
  
  if ThrProcOtp.curr<>nil then
  begin
    var q := ThrProcOtp.curr.q;
    ThrProcOtp.curr := nil;
    lock q do foreach var l in q do Otp(l);
  end;
  
  if e is MessageException then
    Otp(e.Message) else
    Otp(e.ToString);
  
  if is_secondary_proc then
    Halt(e.HResult) else
  begin
    Readln;
    Halt;
  end;
  
end;

{$endregion Otp}

{$region Process execution}

procedure RunFile(fname, nick: string; l_otp: OtpLine->(); params pars: array of string);
begin
  fname := GetFullPath(fname);
  if not System.IO.File.Exists(fname) then raise new System.IO.FileNotFoundException(nil,fname);
  
  MiscUtils.Otp($'Runing {nick}');
  if l_otp=nil then l_otp := l->MiscUtils.Otp(l.ConvStr(s->$'{nick}: {s}'));
  
  var pipe := new System.IO.Pipes.AnonymousPipeServerStream(System.IO.Pipes.PipeDirection.In, System.IO.HandleInheritability.Inheritable);
  
  
  var psi := new ProcessStartInfo(fname, pars.Append($'"{StrConsts.OutputPipeId}={pipe.GetClientHandleAsString}"').JoinToString);
//  pipe.DisposeLocalCopyOfClientHandle; //ToDo разобраться на сколько это надо и куда сувать
  psi.UseShellExecute := false;
  psi.RedirectStandardOutput := true;
  psi.WorkingDirectory := System.IO.Path.GetDirectoryName(fname);
  
  var p := new Process;
  p.StartInfo := psi;
  
  var curr_timer: ExeTimer := Timer.main.exe_exec[nick];
  
  {$region otp capture}
  
  var thr_otp := new ThrProcOtp;
  p.OutputDataReceived += (o,e)->
  try
    if e.Data=nil then
      thr_otp.Finish else
      thr_otp.Enq(e.Data);
  except
    on exc: Exception do ErrOtp(exc);
  end;
  
  var start_time_mark: int64;
  var pipe_connection_established := false;
  Thread.Create(()->
  try
    var br := new System.IO.BinaryReader(pipe);
    
    try
      br.ReadByte;
    except
      on e: System.IO.EndOfStreamException do
      begin
        Otp($'WARNING: Pipe connection with [{nick}] wasn''t established');
        exit;
      end;
    end;
    pipe_connection_established := true;
    
    while true do
    begin
      var otp_type := br.ReadInt32;
      
      case otp_type of
        
        1:
        begin
          var l := new OtpLine;
          l.t := start_time_mark + br.ReadInt64;
          l.s := br.ReadString;
          thr_otp.Enq(l);
        end;
        
        2:
        begin
          thr_otp.Finish;
          curr_timer.MergeLoad(br);
          br.Close; // тоже не обязательно, основной поток тоже его вызовет, но уже после завершения работы .exe
          break;
        end;
        
        else raise new MessageException($'Invalid bin otp type: [{otp_type}]');
      end;
      
    end;
    
  except
    on e: Exception do ErrOtp(e);
  end).Start;
  
  {$endregion otp capture}
  
  lock sec_procs do sec_procs += p;
  curr_timer.MeasureTime(()->
  begin
    start_time_mark := pack_timer.ElapsedTicks;
    p.Start;
    
    try
      
      p.BeginOutputReadLine;
      foreach var l in thr_otp.Enmr do l_otp(l);
      p.WaitForExit;
      
      if p.ExitCode<>0 then
      begin
        var ex := System.Runtime.InteropServices.Marshal.GetExceptionForHR(p.ExitCode);
        ErrOtp(new Exception($'Error in {nick}:', ex));
      end;
      
      MiscUtils.Otp($'Finished runing {nick}');
    finally
      try
        p.Kill;
      except end;
    end;
    
  end);
  
  if not pipe_connection_established then pipe.Close;
end;

procedure CompilePasFile(fname: string; l_otp: OtpLine->(); err: string->());
begin
  fname := GetFullPath(fname);
  var nick := System.IO.Path.GetFileNameWithoutExtension(fname);
  
  foreach var p in Process.GetProcessesByName(nick+'.exe') do
    p.Kill;
  
  if l_otp=nil then l_otp := MiscUtils.Otp;
  if err=nil then err := s->raise new MessageException($'Error compiling "{fname}": {s}');
  
  l_otp($'Compiling "{GetRelativePath(fname)}"');
  
  var psi := new ProcessStartInfo('C:\Program Files (x86)\PascalABC.NET\pabcnetcclear.exe', $'"{fname}"');
  psi.UseShellExecute := false;
  psi.RedirectStandardOutput := true;
  psi.RedirectStandardInput := true;
  
  var p := new Process;
  p.StartInfo := psi;
  
  Timer.main.pas_comp[nick].MeasureTime(()->
  begin
    p.Start;
    p.StandardInput.WriteLine;
    p.WaitForExit;
  end);
  
  var res := p.StandardOutput.ReadToEnd.Remove(#13).Trim(#10' '.ToArray);
  if res.ToLower.Contains('error') then
    err(res) else
    l_otp($'Finished compiling: {res}');
  
end;

procedure ExecuteFile(fname, nick: string; l_otp: OtpLine->(); err: string->(); params pars: array of string);
begin
  fname := GetFullPath(fname);
  
  var ffname := fname.Substring(fname.LastIndexOf('\')+1);
  if ffname.Contains('.') then
    case ffname.Substring(ffname.LastIndexOf('.')) of
      
      '.pas':
      begin
        
        CompilePasFile(fname, l_otp, err);
        
        fname := fname.Remove(fname.LastIndexOf('.'))+'.exe';
        ffname := fname.Substring(fname.LastIndexOf('\')+1);
      end;
      
      '.exe': ;
      
      else raise new MessageException($'Unknown file extention: "{fname}"');
    end else
      raise new MessageException($'file without extention: "{fname}"');
  
  RunFile(fname, nick, l_otp, pars);
end;



procedure RunFile(fname, nick: string; params pars: array of string) :=
RunFile(fname, nick, nil, pars);

procedure CompilePasFile(fname: string) :=
CompilePasFile(fname, nil, nil);

procedure ExecuteFile(fname, nick: string; params pars: array of string) :=
ExecuteFile(fname, nick, nil, nil, pars);

{$endregion Process execution}

{$region Task operations}

type
  SecThrProc = abstract class
    own_otp: ThrProcOtp;
    
    procedure SyncExec; abstract;
    
    function CreateThread := new Thread(()->
    try
      RegisterThr;
      ThrProcOtp.curr := self.own_otp;
      SyncExec;
      self.own_otp.Finish;
    except
      on e: Exception do ErrOtp(e);
    end);
    
    function StartExec: Thread;
    begin
      self.own_otp := new ThrProcOtp;
      Result := CreateThread;
      Result.Start;
    end;
    
  end;
  
  SecThrProcCustom = sealed class(SecThrProc)
    p: Action0;
    constructor(p: Action0) := self.p := p;
    
    procedure SyncExec; override := p;
    
  end;
  
  SecThrProcSum = sealed class(SecThrProc)
    p1,p2: SecThrProc;
    
    constructor(p1,p2: SecThrProc);
    begin
      self.p1 := p1;
      self.p2 := p2;
    end;
    
    procedure SyncExec; override;
    begin
      p1.SyncExec;
      p2.SyncExec;
    end;
    
  end;
  
  SecThrProcMlt = sealed class(SecThrProc)
    p1,p2: SecThrProc;
    
    constructor(p1,p2: SecThrProc);
    begin
      self.p1 := p1;
      self.p2 := p2;
    end;
    
    procedure SyncExec; override;
    begin
      p1.StartExec;
      p2.StartExec;
      
      foreach var l in p1.own_otp.Enmr do Otp(l);
      foreach var l in p2.own_otp.Enmr do Otp(l);
    end;
    
  end;
  
function operator+(p1,p2: SecThrProc): SecThrProc; extensionmethod :=
new SecThrProcSum(p1,p2);
procedure operator+=(var p1: SecThrProc; p2: SecThrProc); extensionmethod :=
p1 := p1+p2;

function operator*(p1,p2: SecThrProc): SecThrProc; extensionmethod :=
new SecThrProcMlt(p1,p2);

function ProcTask(p: Action0): SecThrProc :=
new SecThrProcCustom(p);

function CompTask(fname: string) :=
ProcTask(()->CompilePasFile(fname));

function ExecTask(fname, nick: string; params pars: array of string) :=
ProcTask(()->ExecuteFile(fname, nick, pars));

function EmptyTask := ProcTask(()->exit());

function SetEvTask(ev: ManualResetEvent) := ProcTask(()->begin ev.Set() end);
function EventTask(ev: ManualResetEvent) := ProcTask(()->begin ev.WaitOne() end);

function CombineAsyncTask(self: sequence of SecThrProc): SecThrProc; extensionmethod;
begin
  Result := EmptyTask;
  
  var evs := new List<ManualResetEvent>;
  foreach var t in self do
  begin
    var ev := new ManualResetEvent(false);
    evs += ev;
    
    var T_Wait: SecThrProc := EmptyTask;
    foreach var pev in evs.SkipLast(System.Environment.ProcessorCount+1) do T_Wait:=T_Wait + EventTask(pev);
    
    var T_ver :=
      T_Wait + t +
      SetEvTask(ev)
    ;
    
    Result := Result * T_ver;
  end;
  
end;

{$endregion Task operations}

{$region Fixers}

type
  INamed = interface
    function GetName: string;
  end;
  
  Fixer<TFixer,TFixable> = abstract class where TFixable: INamed, constructor;// where TFixer: Fixer<TFixer,TFixalbe>; //ToDo #2191
    protected name: string;
    protected used: boolean;
    
    private static all := new Dictionary<string, List<TFixer>>;
    private static function GetItem(name: string): List<TFixer>;
    begin
      if not all.TryGetValue(name, Result) then
      begin
        Result := new List<TFixer>;
        all[name] := Result;
      end;
    end;
    public static property Item[name: string]: List<TFixer> read GetItem; default;
    
    private static adders := new List<TFixer>;
    public procedure RegisterAsAdder := adders.Add(TFixer(self as object)); //ToDo #2191, но TFixer() нужно
    
    protected constructor(name: string);
    begin
      self.name := name;
      if name=nil then exit; // внутренний фиксер, то есть или empty, или содержащийся в контейнере
      Item[name].Add( TFixer(self as object) ); //ToDo #2191, но TFixer() нужно
    end;
    
    private static function DetemplateName(name: string; lns: array of string; templ_ind: integer): sequence of (string, array of string);
    begin
      Result := Seq((name,lns));
      var ind1 := name.IndexOf('[');
      if ind1=-1 then exit;
      var ind2 := name.IndexOf(']',ind1+1);
      if ind2=-1 then exit;
      
      var s1 := name.Remove(ind1);
      var s2 := name.Substring(ind2+1);
      
      Result := name.Substring(ind1+1,ind2-ind1-1)
        .Split(',').Select(s->s.Trim)
        .Select(s->( Concat(s1,s,s2), lns.ConvertAll(l->l.Replace($'%{templ_ind}%',s)) ))
        .SelectMany(t->DetemplateName(t[0],t[1],templ_ind+1));
    end;
    protected static function ReadBlocks(lines: sequence of string; power_sign: string; concat_blocks: boolean): sequence of (string, array of string);
    begin
      var res := new List<string>;
      var names := new List<string>;
      
      foreach var l in lines do
        if l.StartsWith(power_sign) then
        begin
          if (res.Count<>0) or not concat_blocks then
          begin
            yield sequence names.SelectMany(name->Fixer&<TFixer,TFixable>.DetemplateName(name, res.ToArray, 0));
            res.Clear;
            names.Clear;
          end;
          names += l.Substring(power_sign.Length).Trim;
        end else
          res += l;
      
      yield sequence names.SelectMany(name->Fixer&<TFixer,TFixable>.DetemplateName(name, res.ToArray, 0));
    end;
    protected static function ReadBlocks(fname: string; concat_blocks: boolean) := ReadBlocks(ReadLines(fname), '#', concat_blocks);
    
    protected function ApplyOrder; virtual := 0;
    /// Return "True" if "o" is deleted
    protected function Apply(o: TFixable): boolean; abstract;
    public static procedure ApplyAll(lst: List<TFixable>);
    begin
      lst.Capacity := lst.Count + adders.Count;
      
      foreach var a in adders do
      begin
        var o := new TFixable;
        (a as object as Fixer<TFixer, TFixable>).Apply(o); //ToDo #2191
        lst += o;
      end;
      
      for var i := lst.Count-1 downto 0 do
      begin
        var o := lst[i];
        foreach var f in Item[o.GetName].OrderBy(f->(f as object as Fixer<TFixer, TFixable>).ApplyOrder) do //ToDo #2191
          if (f as object as Fixer<TFixer, TFixable>).Apply(o) then //ToDo #2191
            lst.RemoveAt(i);
      end;
      
      lst.TrimExcess;
    end;
    
    protected procedure WarnUnused; abstract;
    public static procedure WarnAllUnused :=
    foreach var l in all.Values do
      if l.Any(f->not (f as object as Fixer<TFixer, TFixable>).used) then //ToDo #2191
        (l[0] as object as Fixer<TFixer, TFixable>).WarnUnused; //ToDo #2191
    
  end;
  
{$endregion Fixers}

// потому что лямбды не работают в initialization
///--
procedure InitMiscUtils :=
try
  RegisterThr;
  DefaultEncoding := enc;
  is_secondary_proc := CommandLineArgs.Any(arg->arg.StartsWith(StrConsts.OutputPipeId));
  Timer.main := new ExeTimer;
  
  if is_secondary_proc then
    Logger.main_log := new ParentStreamLogger else
  begin
    Logger.main_log := new ConsoleLogger;
    Console.OutputEncoding := enc;
  end;
  
  while not System.Environment.CurrentDirectory.EndsWith('POCGL') do
    System.Environment.CurrentDirectory := System.IO.Path.GetDirectoryName(System.Environment.CurrentDirectory);
except
  on e: Exception do ErrOtp(e);
end;

initialization
  InitMiscUtils;
finalization
  Logger.main_log.Close;
  if not is_secondary_proc then Readln;
end.