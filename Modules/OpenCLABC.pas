﻿
{%..\LicenseHeader%}

///
///Высокоуровневая оболочка модуля OpenCL
///   OpenCL и OpenCLABC можно использовать одновременно
///   Но контактировать они практически не будут
///
///Если не хватает типа/метода или найдена ошибка - писать сюда:
///   https://github.com/SunSerega/POCGL/issues
///
///Справка данного модуля находится в папке примеров
///   По-умолчанию, её можно найти в "C:\PABCWork.NET\Samples\OpenGL и OpenCL"
///
unit OpenCLABC;

{$region TODO}

//===================================
// Обязательно сделать до следующей стабильной версии:

//TODO Использовать TypeToTypeName и TypeName

//TODO .Add методы не сочитаются со всем остальным модулем
// - Можно сделать .ThenWriteValue, возвращающий новый CCQ
// - Но чтобы не перевыделять массив для каждой комманды - можно чтобы старый и новый CCQ ссылались на общий массив комманд, но имели разные count: integer
// --- Тогда при добавлении в старый CCQ придётся сначала перевыделить массив - но это меньшее зло
// - Пройтись по всем .Add в .pas и .md файлах, позаменять их
// - По случаю поперемещать .dat и .template файлы в кодогенератора: сейчас там мусорка

//TODO В .td сохранять кол-во типов-делегатов, использованных в программе
// - Это можно и без запуска: прочитав сборку сразу после компиляции

//TODO Тесты:
// - CQQ.AddQueue(self)

//TODO Справка:
// - CQQ.AddQueue(self)
// - DiscardResult
// - AddGet не выполняются если их результат не использован

//===================================
// Запланированное:

//TODO cl.WaitForEvents тратит время процессора??? Почему?
//TODO Вроде как реализация может не отсылать комманды некоторое время без cl.Finish (а может cl.Flush?)
//TODO Интегрировать профайлинг очередей
// - И в том числе профайлинг отдельных ивентов

//TODO err_handler: can_cache может лучше заменить на can_cache_from?
// - Сейчас, вроде, can_cache:=false только в одном месте: и там кешировать нельзя НЕ все ноды
// - А нет, вроде can_cache=false вообще только на 1 уровень распространяется, а предыдущие хендлеры всё равно можно кешировать
// - В таком случае параметр лучше вообще убрать, и сделать отдельную HadError, не устанавливающую кеш
// - Ещё перепроверить, перед тем как делать

//TODO KernelArg.FromDataCQ(mu().ThenQConv(data->data.ptr), mu().ThenQConv(data->data.size))
// - Как то корявенько, когда надо из 1 значения сделать FromDataCQ
// - Может альтернативный вариант с передачей какой-то записи?
// - И наверное не только тут пригодится - к примеру SubMemorySegment
// - В то же время если надо из 2 очередей (ptr и size) его сделать Combine.Conv[Sync/Async].N2
// - То есть пользователь сам решает асинхронные ли ветки

//TODO KernelArg.FromArray принимает индекс но не длину
// - А FromCLArray вообще не может ссылаться на диапазон в массиве

//TODO Пройтись по интерфейсу, порасставлять кидание исключений
//TODO Проверки и кидания исключений перед всеми cl.*, чтобы выводить норм сообщения об ошибках
//TODO Попробовать получать информацию о параметрах Kernel'а и выдавать адекватные ошибки, если передают что-то не то
// - Адрес RAM всегда превращается в read-only копию на стороне OpenCL-C?

//TODO Использовать cl.EnqueueMapBuffer
// - В виде .AddMap((MappedArray,Context)->())
// - Недодел своей ветке

//TODO .pcu с неправильной позицией зависимости, или не теми настройками - должен игнорироваться
// - Иначе сейчас модули в примерах ссылаются на .pcu, который существует только во время работы Tester, ломая компилятор

//TODO Порядок Wait очередей в Wait группах
// - Проверить сочетание с каждой другой фичей

//TODO .Cycle(integer)
//TODO .Cycle // бесконечность циклов
//TODO .CycleWhile(***->boolean)
//TODO В продолжение Cycle: Однако всё ещё остаётся проблема - как сделать ветвление?
// - И если уже делать - стоит сделать и метод CQ.ThenIf(res->boolean; if_true, if_false: CQ)
//TODO И ещё - AbortQueue, который, по сути, может использоваться как exit, continue или break, если с обработчиками ошибок
// - Или может метод MarkerQueue.Abort?
//
//TODO Несколько TODO в:
// - Queue converter's >> Wait

//TODO CLArray2 и CLArray3?
// - Основная проблема использовать только CLArray<> сейчас - через него не прочитаешь/не запишешь многомерные массивы из RAM
// - Вообще на стороне OpenCL запутывает, по строкам или по столбцам передался массив?
// - С этой стороны, лучше иметь только одномерный CLArray, ради безопасности
// - По хорошему, в коде использующем OpenCLABC, надо объявляться MatrixByRows/MatrixByCols и т.п.
// - Но это будет объёмно, а ради простых примеров...

//TODO Исправить перегрузки Kernel.Exec

//TODO Проверить, будет ли оптимизацией, создавать свой ThreadPool для каждого CLTaskBase
// - (HPQ+HPQ).Handle.Handle, тут создаётся 4 UserEvent, хотя всё можно было бы выполнять синхронно

//TODO А что если передавать в делегаты QueueRes'ов Context и возможно err_handler
// - Надо будет сразу сравнить скорость

//===================================
// Сделать когда-нибуть:

//TODO Пройтись по всем функциям OpenCL, посмотреть функционал каких не доступен из OpenCLABC
// - clGetKernelWorkGroupInfo - свойства кернела на определённом устройстве
// - clCreateContext: CL_CONTEXT_INTEROP_USER_SYNC

//TODO Слишком новые фичи, которые могут много чего изменить:
// - cl_khr_command_buffer
// --- Буферы, хранящие список комманд
// - cl_khr_semaphore
// --- Как cl_event, но многоразовые

//===================================

{$endregion TODO}

{$region Bugs}

//TODO Issue компилятора:
//TODO https://github.com/pascalabcnet/pascalabcnet/issues/{id}
// - #2221
// - #2550
// - #2589
// - #2604
// - #2607
// - #2610

//TODO Баги NVidia
//TODO https://developer.nvidia.com/nvidia_bug/{id}
// - NV#3035203

{$endregion}

{$region DEBUG}{$ifdef DEBUG}

// Регистрация всех cl.RetainEvent и cl.ReleaseEvent
{ $define EventDebug}

// Регистрация использований cl_command_queue
{ $define QueueDebug}

// Регистрация активаций/деактиваций всех WaitHandler-ов
{ $define WaitDebug}

{ $define ForceMaxDebug}
{$ifdef ForceMaxDebug}
  {$define EventDebug}
  {$define QueueDebug}
  {$define WaitDebug}
{$endif ForceMaxDebug}

{$endif DEBUG}{$endregion DEBUG}

interface

uses System;
uses System.Threading;
uses System.Runtime.InteropServices;
uses System.Runtime.CompilerServices;
uses System.Collections.ObjectModel;
uses System.Collections.Concurrent;

uses OpenCL;

type
  
  {$region Re-definition's}
  
  OpenCLException         = OpenCL.OpenCLException;
  
  DeviceType              = OpenCL.DeviceType;
  DeviceAffinityDomain    = OpenCL.DeviceAffinityDomain;
  
  {$endregion Re-definition's}
  
  {$region OpenCLABCInternalException}
  
  OpenCLABCInternalException = sealed class(Exception)
    
    private constructor(message: string) :=
    inherited Create(message);
//    private constructor(message: string; ec: ErrorCode) :=
//    inherited Create($'{message} with {ec}');
    private constructor(ec: ErrorCode) :=
    inherited Create(OpenCLException.Create(ec).Message);
    private constructor;
    begin
      inherited Create($'%Err:NoParamCtor%');
      raise self;
    end;
    
    private static procedure RaiseIfError(ec: ErrorCode) :=
    if ec.IS_ERROR then raise new OpenCLABCInternalException(ec);
    
    private static procedure RaiseIfError(st: CommandExecutionStatus) :=
    if st.val<0 then RaiseIfError(ErrorCode(st));
    
  end;
  
  {$endregion OpenCLABCInternalException}
  
  {$region DEBUG}
  
  {$region EventDebug}{$ifdef EventDebug}
  
  EventRetainReleaseData = record
    private is_release: boolean;
    private reason: string;
    
    private static debug_time_counter := Stopwatch.StartNew;
    private time: TimeSpan;
    
    public constructor(is_release: boolean; reason: string);
    begin
      self.is_release := is_release;
      self.reason := reason;
      self.time := debug_time_counter.Elapsed;
    end;
    
    private function GetActStr := is_release ? 'Released' : 'Retained';
    public function ToString: string; override :=
    $'{time} | {GetActStr} when: {reason}';
    
  end;
  EventDebug = static class
    
    {$region Retain/Release}
    
    private static RefCounter := new ConcurrentDictionary<cl_event, ConcurrentQueue<EventRetainReleaseData>>;
    private static function RefCounterFor(ev: cl_event) := RefCounter.GetOrAdd(ev, ev->new ConcurrentQueue<EventRetainReleaseData>);
    
    public static procedure RegisterEventRetain(ev: cl_event; reason: string) :=
    RefCounterFor(ev).Enqueue(new EventRetainReleaseData(false, reason));
    public static procedure RegisterEventRelease(ev: cl_event; reason: string);
    begin
      EventDebug.CheckExists(ev, reason);
      RefCounterFor(ev).Enqueue(new EventRetainReleaseData(true, reason));
    end;
    
    public static procedure ReportRefCounterInfo(otp: System.IO.TextWriter := Console.Out) :=
    lock otp do
    begin
      otp.WriteLine(System.Environment.StackTrace);
      
      foreach var kvp in RefCounter do
      begin
        otp.WriteLine($'Logging state change of {kvp.Key}:');
        var c := 0;
        foreach var act in kvp.Value do
        begin
          c += if act.is_release then -1 else +1;
          otp.WriteLine($'{c,3} | {act}');
        end;
        otp.WriteLine('-'*30);
      end;
      
      otp.WriteLine('='*40);
      otp.Flush;
    end;
    
    public static function CountRetains(ev: cl_event) :=
    RefCounter[ev].Sum(act->act.is_release ? -1 : +1);
    public static procedure CheckExists(ev: cl_event; reason: string) :=
    if CountRetains(ev)<=0 then lock output do
    begin
      ReportRefCounterInfo(Console.Error);
      Sleep(1000);
      raise new OpenCLABCInternalException($'Event {ev} was released before last use ({reason}) at');
    end;
    
    public static procedure FinallyReport;
    begin
      foreach var ev in RefCounter.Keys do if CountRetains(ev)<>0 then
      begin
        ReportRefCounterInfo(Console.Error);
        Sleep(1000);
        raise new OpenCLABCInternalException(ev.ToString);
      end;
      var total_ev_count := RefCounter.Values.Sum(q->q.Select(act->act.is_release ? -1 : +1).PartialSum.CountOf(0));
      $'[EventDebug]: {total_ev_count} event''s created'.Println;
    end;
    
    {$endregion Retain/Release}
    
  end;
  
  {$endif EventDebug}{$endregion EventDebug}
  
  {$region QueueDebug}{$ifdef QueueDebug}
  
  QueueDebug = static class
    
    private static QueueUses := new ConcurrentDictionary<cl_command_queue, ConcurrentQueue<string>>;
    private static function QueueUsesFor(cq: cl_command_queue) := QueueUses.GetOrAdd(cq, cq->new ConcurrentQueue<string>);
    private static procedure Add(cq: cl_command_queue; use: string) := QueueUsesFor(cq).Enqueue(use);
    
    public static procedure ReportQueueUses(otp: System.IO.TextWriter := Console.Out) :=
    lock otp do
    begin
      otp.WriteLine(System.Environment.StackTrace);
      
      foreach var kvp in QueueUses do
      begin
        otp.WriteLine($'Logging uses of {kvp.Key}:');
        foreach var use in kvp.Value do
          otp.WriteLine(use);
        otp.WriteLine('-'*30);
      end;
      
      otp.WriteLine('='*40);
      otp.Flush;
    end;
    
    public static procedure FinallyReport;
    begin
      var total_q_count := QueueUses.Keys.Sum(q->
      begin
        Result := 0;
        var last_return := false;
        foreach var use in QueueUses[q] do
        begin
          last_return := ('- return -' in use) or ('- last q -' in use);
          Result += ord(last_return);
        end;
        if last_return then exit;
        ReportQueueUses(Console.Error);
        Sleep(1000);
        raise new OpenCLABCInternalException(q.ToString);
      end);
      $'[QueueDebug]: {total_q_count} queue''s created'.Println;
    end;
    
  end;
  
  {$endif}{$endregion QueueDebug}
  
  {$region WaitDebug}{$ifdef WaitDebug}
  
  WaitDebug = static class
    
    private static WaitActions := new ConcurrentDictionary<object, ConcurrentQueue<string>>;
    
    private static procedure RegisterAction(handler: object; act: string) :=
    WaitActions.GetOrAdd(handler, hc->new System.Collections.Concurrent.ConcurrentQueue<string>).Enqueue(act);
    
    public static procedure ReportWaitActions(otp: System.IO.TextWriter := Console.Out) :=
    lock otp do
    begin
      otp.WriteLine(System.Environment.StackTrace);
      
      foreach var kvp in WaitActions do
      begin
        otp.WriteLine($'Logging actions of handler[{kvp.Key.GetHashCode}]:');
        foreach var act in kvp.Value do
          otp.WriteLine(act);
        otp.WriteLine('-'*30);
      end;
      
      otp.WriteLine('='*40);
      otp.Flush;
    end;
    
    public static procedure FinallyReport;
    begin
      $'[WaitDebug]: {WaitActions.Count} wait handler''s created'.Println;
    end;
    
  end;
  
  {$endif}{$endregion WaitDebug}
  
  {$endregion DEBUG}
  
  {$region Properties}
  
  {%WrapperProperties\Interface!WrapperProperties.pas%}
  
  {$endregion Properties}
  
  {$region Wrappers}
  // Для параметров команд
  CommandQueue<T> = abstract partial class end;
  KernelArg = abstract partial class end;
  
  {$region Platform}
  
  Platform = partial class
    private ntv: cl_platform_id;
    
    public constructor(ntv: cl_platform_id) := self.ntv := ntv;
    private constructor := raise new OpenCLABCInternalException;
    
    private static all_need_init := true;
    private static _all: IList<Platform>;
    private static function GetAll: IList<Platform>;
    begin
      if all_need_init then
      begin
        var c: UInt32;
        OpenCLABCInternalException.RaiseIfError(
          cl.GetPlatformIDs(0, IntPtr.Zero, c)
        );
        
        if c<>0 then
        begin
          var all_arr := new cl_platform_id[c];
          OpenCLABCInternalException.RaiseIfError(
            cl.GetPlatformIDs(c, all_arr[0], IntPtr.Zero)
          );
          
          _all := new ReadOnlyCollection<Platform>(all_arr.ConvertAll(pl->new Platform(pl)));
        end else
          _all := nil;
        
        all_need_init := false;
      end;
      Result := _all;
    end;
    public static property All: IList<Platform> read GetAll;
    
    public function ToString: string; override :=
    $'{self.GetType.Name}[{ntv.val}]';
    
  end;
  
  {$endregion Platform}
  
  {$region Device}
  
  Device = partial class
    private ntv: cl_device_id;
    
    private constructor(ntv: cl_device_id) := self.ntv := ntv;
    public static function FromNative(ntv: cl_device_id): Device;
    
    private constructor := raise new OpenCLABCInternalException;
    
    private function GetBasePlatform: Platform;
    begin
      var pl: cl_platform_id;
      OpenCLABCInternalException.RaiseIfError(
        cl.GetDeviceInfo(self.ntv, DeviceInfo.DEVICE_PLATFORM, new UIntPtr(sizeof(cl_platform_id)), pl, IntPtr.Zero)
      );
      Result := new Platform(pl);
    end;
    public property BasePlatform: Platform read GetBasePlatform;
    
    public static function GetAllFor(pl: Platform; t: DeviceType): array of Device;
    begin
      
      var c: UInt32;
      var ec := cl.GetDeviceIDs(pl.ntv, t, 0, IntPtr.Zero, c);
      if ec=ErrorCode.DEVICE_NOT_FOUND then exit;
      OpenCLABCInternalException.RaiseIfError(ec);
      
      var all := new cl_device_id[c];
      OpenCLABCInternalException.RaiseIfError(
        cl.GetDeviceIDs(pl.ntv, t, c, all[0], IntPtr.Zero)
      );
      
      Result := all.ConvertAll(dvc->new Device(dvc));
    end;
    public static function GetAllFor(pl: Platform) := GetAllFor(pl, DeviceType.DEVICE_TYPE_GPU);
    
    public function ToString: string; override :=
    $'{self.GetType.Name}[{ntv.val}]';
    
  end;
  
  {$endregion Device}
  
  {$region SubDevice}
  
  SubDevice = partial class(Device)
    private _parent: cl_device_id;
    public property Parent: Device read Device.FromNative(_parent);
    
    private constructor(parent, ntv: cl_device_id);
    begin
      inherited Create(ntv);
      self._parent := parent;
    end;
    
    private constructor := inherited;
    
    protected procedure Finalize; override :=
    OpenCLABCInternalException.RaiseIfError(cl.ReleaseDevice(ntv));
    
    public function ToString: string; override :=
    $'{inherited ToString} of {Parent}';
    
  end;
  
  {$endregion SubDevice}
  
  {$region Context}
  
  Context = partial class
    private ntv: cl_context;
    
    private dvcs: IList<Device>;
    public property AllDevices: IList<Device> read dvcs;
    
    private main_dvc: Device;
    public property MainDevice: Device        read main_dvc;
    
    private function GetAllNtvDevices: array of cl_device_id;
    begin
      Result := new cl_device_id[dvcs.Count];
      for var i := 0 to Result.Length-1 do
        Result[i] := dvcs[i].ntv;
    end;
    
    public function ToString: string; override :=
    $'{self.GetType.Name}[{ntv.val}] on devices: [{AllDevices.JoinToString('', '')}]; Main device: {MainDevice}';
    
    {$region Default}
    
    private static default_was_inited := 0;
    private static _default: Context;
    
    private static function GetDefault: Context;
    begin
      if Interlocked.CompareExchange(default_was_inited, 1, 0)=0 then
        Interlocked.CompareExchange(_default, MakeNewDefaultContext, nil);
      Result := _default;
    end;
    private static procedure SetDefault(new_default: Context);
    begin
      default_was_inited := 1;
      _default := new_default;
    end;
    public static property &Default: Context read GetDefault write SetDefault;
    
    protected static function MakeNewDefaultContext: Context;
    begin
      Result := nil;
      
      var pls := Platform.All;
      if pls=nil then exit;
      
      foreach var pl in pls do
      begin
        var dvcs := Device.GetAllFor(pl);
        if dvcs=nil then continue;
        Result := new Context(dvcs);
        exit;
      end;
      
      foreach var pl in pls do
      begin
        var dvcs := Device.GetAllFor(pl, DeviceType.DEVICE_TYPE_ALL);
        if dvcs=nil then continue;
        Result := new Context(dvcs);
        exit;
      end;
      
    end;
    
    {$endregion Default}
    
    {$region constructor's}
    
    private static procedure CheckMainDevice(main_dvc: Device; dvc_lst: IList<Device>) :=
    if not dvc_lst.Contains(main_dvc) then raise new ArgumentException($'%Err:Context:WrongMainDvc%');
    
    public constructor(dvcs: IList<Device>; main_dvc: Device);
    begin
      CheckMainDevice(main_dvc, dvcs);
      
      var ntv_dvcs := new cl_device_id[dvcs.Count];
      for var i := 0 to ntv_dvcs.Length-1 do
        ntv_dvcs[i] := dvcs[i].ntv;
      
      var ec: ErrorCode;
      self.ntv := cl.CreateContext(nil, ntv_dvcs.Count, ntv_dvcs, nil, IntPtr.Zero, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
      
      self.dvcs := if dvcs.IsReadOnly then dvcs else new ReadOnlyCollection<Device>(dvcs.ToArray);
      self.main_dvc := main_dvc;
    end;
    public constructor(params dvcs: array of Device) := Create(dvcs, dvcs[0]);
    
    protected static function GetContextDevices(ntv: cl_context): array of Device;
    begin
      
      var sz: UIntPtr;
      OpenCLABCInternalException.RaiseIfError(
        cl.GetContextInfo(ntv, ContextInfo.CONTEXT_DEVICES, UIntPtr.Zero, nil, sz)
      );
      
      var res := new cl_device_id[uint64(sz) div Marshal.SizeOf&<cl_device_id>];
      OpenCLABCInternalException.RaiseIfError(
        cl.GetContextInfo(ntv, ContextInfo.CONTEXT_DEVICES, sz, res[0], IntPtr.Zero)
      );
      
      Result := res.ConvertAll(dvc->new Device(dvc));
    end;
    private procedure InitFromNtv(ntv: cl_context; dvcs: IList<Device>; main_dvc: Device);
    begin
      CheckMainDevice(main_dvc, dvcs);
      OpenCLABCInternalException.RaiseIfError( cl.RetainContext(ntv) );
      self.ntv := ntv;
      // Копирование должно происходить в вызывающих методах
      self.dvcs := if dvcs.IsReadOnly then dvcs else new ReadOnlyCollection<Device>(dvcs);
      self.main_dvc := main_dvc;
    end;
    public constructor(ntv: cl_context; main_dvc: Device) :=
    InitFromNtv(ntv, GetContextDevices(ntv), main_dvc);
    
    public constructor(ntv: cl_context);
    begin
      var dvcs := GetContextDevices(ntv);
      InitFromNtv(ntv, dvcs, dvcs[0]);
    end;
    
    private constructor(c: Context; main_dvc: Device) :=
    InitFromNtv(c.ntv, c.dvcs, main_dvc);
    public function MakeSibling(new_main_dvc: Device) := new Context(self, new_main_dvc);
    
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure Dispose;
    begin
      var prev := Interlocked.Exchange(self.ntv.val, IntPtr.Zero);
      if prev=IntPtr.Zero then exit;
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseContext(new cl_context(prev)) );
    end;
    protected procedure Finalize; override := Dispose;
    
    {$endregion constructor's}
    
  end;
  
  {$endregion Context}
  
  {$region ProgramCode}
  
  ProgramCode = partial class
    private ntv: cl_program;
    
    private _c: Context;
    public property BaseContext: Context read _c;
    
    public function ToString: string; override :=
    $'{self.GetType.Name}[{ntv.val}]';
    
    {$region constructor's}
    
    private procedure Build;
    begin
      var ec := cl.BuildProgram(self.ntv, _c.dvcs.Count,_c.GetAllNtvDevices, nil, nil,IntPtr.Zero);
      if not ec.IS_ERROR then exit;
      
      if ec=ErrorCode.BUILD_PROGRAM_FAILURE then
      begin
        var sb := new StringBuilder($'%Err:ProgramCode:BuildFail%');
        
        foreach var dvc in _c.AllDevices do
        begin
          sb += #10#10;
          sb += dvc.ToString;
          sb += ':'#10;
          
          var sz: UIntPtr;
          OpenCLABCInternalException.RaiseIfError(
            cl.GetProgramBuildInfo(self.ntv, dvc.ntv, ProgramBuildInfo.PROGRAM_BUILD_LOG, UIntPtr.Zero,IntPtr.Zero,sz)
          );
          
          var str_ptr := Marshal.AllocHGlobal(IntPtr(pointer(sz)));
          try
            OpenCLABCInternalException.RaiseIfError(
              cl.GetProgramBuildInfo(self.ntv, dvc.ntv, ProgramBuildInfo.PROGRAM_BUILD_LOG, sz,str_ptr,IntPtr.Zero)
            );
            sb += Marshal.PtrToStringAnsi(str_ptr);
          finally
            Marshal.FreeHGlobal(str_ptr);
          end;
          
        end;
        
        raise new OpenCLException(ec, sb.ToString);
      end else
        OpenCLABCInternalException.RaiseIfError(ec);
      
    end;
    
    public constructor(c: Context; params file_texts: array of string);
    begin
      
      var ec: ErrorCode;
      self.ntv := cl.CreateProgramWithSource(c.ntv, file_texts.Length, file_texts, nil, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
      
      self._c := c;
      self.Build;
    end;
    public constructor(params file_texts: array of string) := Create(Context.Default, file_texts);
    
    private constructor(ntv: cl_program; c: Context);
    begin
      OpenCLABCInternalException.RaiseIfError( cl.RetainProgram(ntv) );
      self._c := c;
      self.ntv := ntv;
    end;
    
    private static function GetProgContext(ntv: cl_program): Context;
    begin
      var c: cl_context;
      OpenCLABCInternalException.RaiseIfError(
        cl.GetProgramInfo(ntv, ProgramInfo.PROGRAM_CONTEXT, new UIntPtr(Marshal.SizeOf&<cl_context>), c, IntPtr.Zero)
      );
      Result := new Context(c);
    end;
    public constructor(ntv: cl_program) :=
    Create(ntv, GetProgContext(ntv));
    
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure Dispose;
    begin
      var prev := Interlocked.Exchange(self.ntv.val, IntPtr.Zero);
      if prev=IntPtr.Zero then exit;
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseProgram(new cl_program(prev)) );
    end;
    protected procedure Finalize; override := Dispose;
    
    {$endregion constructor's}
    
    {$region Serialize}
    
    public function Serialize: array of array of byte;
    begin
      var sz: UIntPtr;
      
      OpenCLABCInternalException.RaiseIfError( cl.GetProgramInfo(ntv, ProgramInfo.PROGRAM_BINARY_SIZES, UIntPtr.Zero, nil, sz) );
      var szs := new UIntPtr[sz.ToUInt64 div sizeof(UIntPtr)];
      OpenCLABCInternalException.RaiseIfError( cl.GetProgramInfo(ntv, ProgramInfo.PROGRAM_BINARY_SIZES, sz, szs[0], IntPtr.Zero) );
      
      var res := new IntPtr[szs.Length];
      SetLength(Result, szs.Length);
      
      for var i := 0 to szs.Length-1 do res[i] := Marshal.AllocHGlobal(IntPtr(pointer(szs[i])));
      try
        OpenCLABCInternalException.RaiseIfError(
          cl.GetProgramInfo(ntv, ProgramInfo.PROGRAM_BINARIES, sz, res[0], IntPtr.Zero)
        );
        for var i := 0 to szs.Length-1 do
        begin
          var a := new byte[szs[i].ToUInt64];
          Marshal.Copy(res[i], a, 0, a.Length);
          Result[i] := a;
        end;
      finally
        for var i := 0 to szs.Length-1 do Marshal.FreeHGlobal(res[i]);
      end;
      
    end;
    
    public procedure SerializeTo(bw: System.IO.BinaryWriter);
    begin
      var bin := Serialize;
      
      bw.Write(bin.Length);
      foreach var a in bin do
      begin
        bw.Write(a.Length);
        bw.Write(a);
      end;
      
    end;
    public procedure SerializeTo(str: System.IO.Stream) :=
    SerializeTo(new System.IO.BinaryWriter(str));
    
    {$endregion Serialize}
    
    {$region Deserialize}
    
    public static function Deserialize(c: Context; bin: array of array of byte): ProgramCode;
    begin
      var ntv: cl_program;
      
      var dvcs := c.GetAllNtvDevices;
      
      var ec: ErrorCode;
      ntv := cl.CreateProgramWithBinary(
        c.ntv, dvcs.Length, dvcs[0],
        bin.ConvertAll(a->new UIntPtr(a.Length))[0], bin,
        IntPtr.Zero, ec
      );
      OpenCLABCInternalException.RaiseIfError(ec);
      
      Result := new ProgramCode(ntv, c);
      Result.Build;
      
    end;
    
    public static function DeserializeFrom(c: Context; br: System.IO.BinaryReader): ProgramCode;
    begin
      var bin: array of array of byte;
      
      SetLength(bin, br.ReadInt32);
      for var i := 0 to bin.Length-1 do
      begin
        var len := br.ReadInt32;
        bin[i] := br.ReadBytes(len);
        if bin[i].Length<>len then raise new System.IO.EndOfStreamException;
      end;
      
      Result := Deserialize(c, bin);
    end;
    public static function DeserializeFrom(c: Context; str: System.IO.Stream) :=
    DeserializeFrom(c, new System.IO.BinaryReader(str));
    
    {$endregion Deserialize}
    
  end;
  
  {$endregion ProgramCode}
  
  {$region Kernel}
  
  Kernel = partial class
    private ntv: cl_kernel;
    
    private code: ProgramCode;
    public property CodeContainer: ProgramCode read code;
    
    private k_name: string;
    public property Name: string read k_name;
    
    public function ToString: string; override :=
    $'{self.GetType.Name}[{Name}:{ntv.val}] from {code}';
    
    {$region constructor's}
    
    protected function MakeNewNtv: cl_kernel;
    begin
      var ec: ErrorCode;
      Result := cl.CreateKernel(code.ntv, k_name, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
    end;
    private constructor(code: ProgramCode; name: string);
    begin
      self.code := code;
      self.k_name := name;
      self.ntv := self.MakeNewNtv;
    end;
    
    public constructor(ntv: cl_kernel; retain: boolean := true);
    begin
      
      var code_ntv: cl_program;
      OpenCLABCInternalException.RaiseIfError(
        cl.GetKernelInfo(ntv, KernelInfo.KERNEL_PROGRAM, new UIntPtr(cl_program.Size), code_ntv, IntPtr.Zero)
      );
      self.code := new ProgramCode(code_ntv);
      
      var sz: UIntPtr;
      OpenCLABCInternalException.RaiseIfError(
        cl.GetKernelInfo(ntv, KernelInfo.KERNEL_FUNCTION_NAME, UIntPtr.Zero, nil, sz)
      );
      var str_ptr := Marshal.AllocHGlobal(IntPtr(pointer(sz)));
      try
        OpenCLABCInternalException.RaiseIfError(
          cl.GetKernelInfo(ntv, KernelInfo.KERNEL_FUNCTION_NAME, sz, str_ptr, IntPtr.Zero)
        );
        self.k_name := Marshal.PtrToStringAnsi(str_ptr);
      finally
        Marshal.FreeHGlobal(str_ptr);
      end;
      
      if retain then OpenCLABCInternalException.RaiseIfError( cl.RetainKernel(ntv) );
      self.ntv := ntv;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure Dispose;
    begin
      var prev := Interlocked.Exchange(self.ntv.val, IntPtr.Zero);
      if prev=IntPtr.Zero then exit;
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseKernel(new cl_kernel(prev)) );
    end;
    protected procedure Finalize; override := Dispose;
    
    {$endregion constructor's}
    
    {$region UseExclusiveNative}
    
    private ntv_in_use := 0;
    protected [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure UseExclusiveNative(p: cl_kernel->()) :=
    if Interlocked.CompareExchange(ntv_in_use, 1, 0)=0 then
    try
      p(self.ntv);
    finally
      ntv_in_use := 0;
    end else
    begin
      var k := MakeNewNtv;
      try
        p(k);
      finally
        OpenCLABCInternalException.RaiseIfError( cl.ReleaseKernel(k) );
      end;
    end;
    protected [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function UseExclusiveNative<T>(f: cl_kernel->T): T;
    begin
      
      if Interlocked.CompareExchange(ntv_in_use, 1, 0)=0 then
      try
        Result := f(self.ntv);
      finally
        ntv_in_use := 0;
      end else
      begin
        var k := MakeNewNtv;
        try
          Result := f(k);
        finally
          OpenCLABCInternalException.RaiseIfError( cl.ReleaseKernel(k) );
        end;
      end;
      
    end;
    
    {$endregion UseExclusiveNative}
    
    {%ContainerMethods\Kernel\Implicit.Interface!ContainerMethods.pas%}
    
  end;
  
  ProgramCode = partial class
    
    public property KernelByName[kname: string]: Kernel read new Kernel(self, kname); default;
    
    public function GetAllKernels: array of Kernel;
    begin
      
      var c: UInt32;
      OpenCLABCInternalException.RaiseIfError( cl.CreateKernelsInProgram(ntv, 0, IntPtr.Zero, c) );
      
      var res := new cl_kernel[c];
      OpenCLABCInternalException.RaiseIfError( cl.CreateKernelsInProgram(ntv, c, res[0], IntPtr.Zero) );
      
      Result := res.ConvertAll(k->new Kernel(k, false));
    end;
    
  end;
  
  {$endregion Kernel}
  
  {$region NativeValue}
  
  NativeValue<T> = partial class(System.IDisposable)
  where T: record;
    private ptr := Marshal.AllocHGlobal(Marshal.SizeOf&<T>);
    
    public constructor(o: T) := self.Value := o;
    public static function operator implicit(o: T): NativeValue<T> := new NativeValue<T>(o);
    
    private function PtrUntyped := pointer(ptr);
    public property Pointer: ^T read PtrUntyped();
    public property Value: T read Pointer^ write Pointer^ := value;
    
    public procedure Dispose;
    begin
      var l_ptr := Interlocked.Exchange(self.ptr, IntPtr.Zero);
      Marshal.FreeHGlobal(l_ptr);
    end;
    protected procedure Finalize; override := Dispose;
    
  end;
  
  {$endregion NativeValue}
  
  {$region MemorySegment}
  
  MemorySegment = partial class
    private ntv: cl_mem;
    
    private static function GetSize(ntv: cl_mem): UIntPtr;
    begin
      OpenCLABCInternalException.RaiseIfError(
        cl.GetMemObjectInfo(ntv, MemInfo.MEM_SIZE, new UIntPtr(UIntPtr.Size), Result, IntPtr.Zero)
      );
    end;
    public property Size: UIntPtr read GetSize(ntv);
    public property Size32: UInt32 read Size.ToUInt32;
    public property Size64: UInt64 read Size.ToUInt64;
    
    public function ToString: string; override :=
    $'{self.GetType.Name}[{ntv.val}] of size {Size}';
    
    {$region constructor's}
    
    public constructor(size: UIntPtr; c: Context);
    begin
      
      var ec: ErrorCode;
      self.ntv := cl.CreateBuffer(c.ntv, MemFlags.MEM_READ_WRITE, size, IntPtr.Zero, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
      
      GC.AddMemoryPressure(size.ToUInt64);
      
    end;
    public constructor(size: integer; c: Context) := Create(new UIntPtr(size), c);
    public constructor(size: int64; c: Context)   := Create(new UIntPtr(size), c);
    
    public constructor(size: UIntPtr) := Create(size, Context.Default);
    public constructor(size: integer) := Create(new UIntPtr(size));
    public constructor(size: int64)   := Create(new UIntPtr(size));
    
    private constructor(ntv: cl_mem);
    begin
      self.ntv := ntv;
      cl.RetainMemObject(ntv);
    end;
    public static function FromNative(ntv: cl_mem): MemorySegment;
    
    private constructor := raise new OpenCLABCInternalException;
    
    {$endregion constructor's}
    
    {%ContainerMethods\MemorySegment\Implicit.Interface!ContainerMethods.pas%}
    
    {%ContainerMethods\MemorySegment.Get\Implicit.Interface!ContainerGetMethods.pas%}
    
    private procedure InformGCOfRelease(prev_ntv: cl_mem); virtual :=
    GC.RemoveMemoryPressure( GetSize(prev_ntv).ToUInt64 );
    
    public procedure Dispose;
    begin
      var prev_ntv := new cl_mem( Interlocked.Exchange(self.ntv.val, IntPtr.Zero) );
      if prev_ntv=cl_mem.Zero then exit;
      InformGCOfRelease(prev_ntv);
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseMemObject(prev_ntv) );
    end;
    protected procedure Finalize; override := Dispose;
    
  end;
  
  {$endregion MemorySegment}
  
  {$region MemorySubSegment}
  
  MemorySubSegment = partial class(MemorySegment)
    
    // Только чтоб не вызвалось GC.RemoveMemoryPressure
    private parent_dispose_lock: MemorySegment;
    
    private _parent: cl_mem;
    public property Parent: MemorySegment read MemorySegment.FromNative(_parent);
    
    public function ToString: string; override :=
    $'{inherited ToString} inside {Parent}';
    
    {$region constructor's}
    
    private static function MakeSubNtv(parent: cl_mem; reg: cl_buffer_region): cl_mem;
    begin
      var ec: ErrorCode;
      Result := cl.CreateSubBuffer(parent, MemFlags.MEM_READ_WRITE, BufferCreateType.BUFFER_CREATE_TYPE_REGION, reg, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
    end;
    
    public constructor(parent: MemorySegment; origin, size: UIntPtr);
    begin
      inherited Create( MakeSubNtv(parent.ntv, new cl_buffer_region(origin, size)) );
      self._parent := parent.ntv;
      self.parent_dispose_lock := parent;
    end;
    public constructor(parent: MemorySegment; origin, size: UInt32) := Create(parent, new UIntPtr(origin), new UIntPtr(size));
    public constructor(parent: MemorySegment; origin, size: UInt64) := Create(parent, new UIntPtr(origin), new UIntPtr(size));
    
    private constructor(parent, ntv: cl_mem);
    begin
      inherited Create(ntv);
      self.parent_dispose_lock := nil;
      self._parent := parent;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    {$endregion constructor's}
    
    private procedure InformGCOfRelease(prev_ntv: cl_mem); override := exit;
    
  end;
  
  {$endregion MemorySubSegment}
  
  {$region CLArray}
  
  CLArray<T> = partial class
  where T: record;
    private ntv: cl_mem;
    
    private len: integer;
    public property Length: integer read len;
    public property ByteSize: int64 read int64(len) * Marshal.SizeOf&<T>;
    
    public function ToString: string; override :=
    $'{self.GetType.Name.Remove(self.GetType.Name.IndexOf(''`''))}<{typeof(T).Name}>[{ntv.val}] of size {Length}';
    
    {$region constructor's}
    
    private procedure InitByLen(c: Context);
    begin
      
      var ec: ErrorCode;
      self.ntv := cl.CreateBuffer(c.ntv, MemFlags.MEM_READ_WRITE, new UIntPtr(ByteSize), IntPtr.Zero, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
      
      GC.AddMemoryPressure(ByteSize);
    end;
    private procedure InitByVal(c: Context; var els: T);
    begin
      
      var ec: ErrorCode;
      self.ntv := cl.CreateBuffer(c.ntv, MemFlags.MEM_READ_WRITE + MemFlags.MEM_COPY_HOST_PTR, new UIntPtr(ByteSize), els, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
      
      GC.AddMemoryPressure(ByteSize);
    end;
    
    public constructor(c: Context; len: integer);
    begin
      self.len := len;
      InitByLen(c);
    end;
    public constructor(len: integer) := Create(Context.Default, len);
    
    public constructor(c: Context; els: array of T);
    begin
      self.len := els.Length;
      InitByVal(c, els[0]);
    end;
    public constructor(els: array of T) := Create(Context.Default, els);
    
    public constructor(c: Context; els_from, len: integer; params els: array of T);
    begin
      self.len := len;
      InitByVal(c, els[els_from]);
    end;
    public constructor(els_from, len: integer; params els: array of T) := Create(Context.Default, els_from, len, els);
    
    public constructor(ntv: cl_mem);
    begin
      
      var byte_size: UIntPtr;
      OpenCLABCInternalException.RaiseIfError(
        cl.GetMemObjectInfo(ntv, MemInfo.MEM_SIZE, new UIntPtr(Marshal.SizeOf&<UIntPtr>), byte_size, IntPtr.Zero)
      );
      
      self.len := byte_size.ToUInt64 div Marshal.SizeOf&<T>;
      self.ntv := ntv;
      
      OpenCLABCInternalException.RaiseIfError( cl.RetainMemObject(ntv) );
      GC.AddMemoryPressure(ByteSize);
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    {$endregion constructor's}
    
    private function GetItemProp(ind: integer): T;
    private procedure SetItemProp(ind: integer; value: T);
    public property Item[ind: integer]: T read GetItemProp write SetItemProp; default;
    
    private function GetSectionProp(range: IntRange): array of T;
    private procedure SetSectionProp(range: IntRange; value: array of T);
    public property Section[range: IntRange]: array of T read GetSectionProp write SetSectionProp;
    
    public procedure Dispose;
    begin
      var prev := Interlocked.Exchange(self.ntv.val, IntPtr.Zero);
      if prev=IntPtr.Zero then exit;
      GC.RemoveMemoryPressure(ByteSize);
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseMemObject(new cl_mem(prev)) );
    end;
    protected procedure Finalize; override := Dispose;
    
    {%ContainerMethods\CLArray\Implicit.Interface!ContainerMethods.pas%}
    
    {%ContainerMethods\CLArray.Get\Implicit.Interface!ContainerGetMethods.pas%}
    
  end;
  
  {$endregion CLArray}
  
  {$region Common}
  
  {%Wrappers\Common!Wrappers.pas%}
  
  {$endregion Common}
  
  {$region Misc}
  
  Device = partial class
    
    private supported_split_modes: array of DevicePartitionProperty := nil;
    private function GetSSM: array of DevicePartitionProperty;
    begin
      if supported_split_modes=nil then supported_split_modes := {%>Properties.PartitionType!!} nil {%};
      Result := supported_split_modes;
    end;
    
    private function Split(params props: array of DevicePartitionProperty): array of SubDevice;
    begin
      if not GetSSM.Contains(props[0]) then
        raise new NotSupportedException($'%Err:Device:SplitNotSupported%');
      
      var c: UInt32;
      OpenCLABCInternalException.RaiseIfError( cl.CreateSubDevices(self.ntv, props, 0, IntPtr.Zero, c) );
      
      var res := new cl_device_id[int64(c)];
      OpenCLABCInternalException.RaiseIfError( cl.CreateSubDevices(self.ntv, props, c, res[0], IntPtr.Zero) );
      
      Result := res.ConvertAll(sdvc->new SubDevice(self.ntv, sdvc));
    end;
    
    public property CanSplitEqually: boolean read DevicePartitionProperty.DEVICE_PARTITION_EQUALLY in GetSSM;
    public function SplitEqually(CUCount: integer): array of SubDevice;
    begin
      if CUCount <= 0 then raise new ArgumentException($'%Err:Device:SplitCUCount%');
      Result := Split(
        DevicePartitionProperty.DEVICE_PARTITION_EQUALLY,
        DevicePartitionProperty.Create(CUCount),
        DevicePartitionProperty.Create(0)
      );
    end;
    
    public property CanSplitByCounts: boolean read DevicePartitionProperty.DEVICE_PARTITION_BY_COUNTS in GetSSM;
    public function SplitByCounts(params CUCounts: array of integer): array of SubDevice;
    begin
      foreach var CUCount in CUCounts do
        if CUCount <= 0 then raise new ArgumentException($'%Err:Device:SplitCUCount%');
      
      var props := new DevicePartitionProperty[CUCounts.Length+2];
      props[0] := DevicePartitionProperty.DEVICE_PARTITION_BY_COUNTS;
      for var i := 0 to CUCounts.Length-1 do
        props[i+1] := new DevicePartitionProperty(CUCounts[i]);
      props[props.Length-1] := DevicePartitionProperty.DEVICE_PARTITION_BY_COUNTS_LIST_END;
      
      Result := Split(props);
    end;
    
    public property CanSplitByAffinityDomain: boolean read DevicePartitionProperty.DEVICE_PARTITION_BY_AFFINITY_DOMAIN in GetSSM;
    public function SplitByAffinityDomain(affinity_domain: DeviceAffinityDomain) :=
    Split(
      DevicePartitionProperty.DEVICE_PARTITION_BY_AFFINITY_DOMAIN,
      DevicePartitionProperty.Create(new IntPtr(affinity_domain.val)),
      DevicePartitionProperty.Create(0)
    );
    
  end;
  
  {$endregion Misc}
  
  {$endregion Wrappers}
  
  {$region CommandQueue}
  
  {$region ToString}
  
  CommandQueueBase = abstract partial class
    
    private static function DisplayNameForType(t: System.Type): string;
    begin
      Result := t.Name;
      
      if t.IsGenericType then
      begin
        var ind := Result.IndexOf('`');
        Result := Result.Remove(ind) + '<' + t.GenericTypeArguments.JoinToString(', ') + '>';
      end;
      
    end;
    private function DisplayName: string; virtual := DisplayNameForType(self.GetType);
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); abstract;
    
    private static function GetValueRuntimeType<T>(val: T) :=
    if typeof(T).IsValueType then
      typeof(T) else
    if val = default(T) then
      nil else val.GetType;
    private static procedure ToStringRuntimeValue<T>(sb: StringBuilder; val: T);
    begin
      var rt := GetValueRuntimeType(val);
      if typeof(T) <> rt then
      begin
        sb.Append(rt);
        sb += '{ ';
      end;
      if rt<>nil then
        sb.Append(_ObjectToString(val)) else
        sb += 'nil';
      if typeof(T) <> rt then
        sb += ' }';
    end;
    
    private function ToStringHeader(sb: StringBuilder; index: Dictionary<object,integer>): boolean;
    begin
      sb += DisplayName;
      
      var ind: integer;
      Result := not index.TryGetValue(self, ind);
      
      if Result then
      begin
        ind := index.Count;
        index[self] := ind;
      end;
      
      sb += '#';
      sb.Append(ind);
      
    end;
    private static procedure ToStringWriteDelegate(sb: StringBuilder; d: System.Delegate);
    begin
      if d.Target<>nil then
      begin
        sb += d.Target.ToString;
        sb += ' => ';
      end;
      sb += d.Method.ToString;
    end;
    private procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>; write_tabs: boolean := true);
    begin
      delayed.Remove(self);
      
      if write_tabs then sb.Append(#9, tabs);
      ToStringHeader(sb, index);
      ToStringImpl(sb, tabs+1, index, delayed);
      
      if tabs=0 then foreach var q in delayed do
      begin
        sb += #10;
        q.ToString(sb, 0, index, new HashSet<CommandQueueBase>);
      end;
      
    end;
    
    public function ToString: string; override;
    begin
      var sb := new StringBuilder;
      ToString(sb, 0, new Dictionary<object, integer>, new HashSet<CommandQueueBase>);
      Result := sb.ToString;
    end;
    
    public function Print: CommandQueueBase;
    begin
      Write(self.ToString);
      Result := self;
    end;
    public function Println: CommandQueueBase;
    begin
      Writeln(self.ToString);
      Result := self;
    end;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    public function Print: CommandQueueNil;
    begin
      inherited Print;
      Result := self;
    end;
    public function Println: CommandQueueNil;
    begin
      inherited Println;
      Result := self;
    end;
    
  end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    public function Print: CommandQueue<T>;
    begin
      inherited Print;
      Result := self;
    end;
    public function Println: CommandQueue<T>;
    begin
      inherited Println;
      Result := self;
    end;
    
  end;
  
  {$endregion ToString}
  
  {$region Use/Convert Typed}
  
  ITypedCQUser = interface
    
    procedure UseNil(cq: CommandQueueNil);
    procedure Use<T>(cq: CommandQueue<T>);
    
  end;
  ITypedCQConverter<TRes> = interface
    
    function ConvertNil(cq: CommandQueueNil): TRes;
    function Convert<T>(cq: CommandQueue<T>): TRes;
    
  end;
  
  CommandQueueBase = abstract partial class
    
    public procedure UseTyped(user: ITypedCQUser); abstract;
    public function ConvertTyped<TRes>(converter: ITypedCQConverter<TRes>): TRes; abstract;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    public procedure UseTyped(user: ITypedCQUser); override := user.UseNil(self);
    public function ConvertTyped<TRes>(converter: ITypedCQConverter<TRes>): TRes; override := converter.ConvertNil(self);
    
  end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    public procedure UseTyped(user: ITypedCQUser); override := user.Use(self);
    public function ConvertTyped<TRes>(converter: ITypedCQConverter<TRes>): TRes; override := converter.Convert(self);
    
  end;
  
  {$endregion Use/Convert Typed}
  
  {$region Const}
  
  ConstQueue<T> = sealed partial class(CommandQueue<T>)
    private res: T;
    
    public constructor(o: T) := self.res := o;
    private constructor := raise new OpenCLABCInternalException;
    
    public property Value: T read res write res;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringRuntimeValue(sb, self.res);
      sb += #10;
    end;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase) end;
  CommandQueue<T> = abstract partial class
    
    public static function operator implicit(o: T): CommandQueue<T> :=
    new ConstQueue<T>(o);
    
  end;
  
  {$endregion Const}
  
  {$region Parameter}
  
  ParameterQueueSetter = sealed partial class
    private val: object;
    
    private constructor := raise new OpenCLABCInternalException;
    
  end;
  ParameterQueue<T> = sealed partial class(CommandQueue<T>)
    private _name: string;
    private def: T;
    private def_is_set: boolean;
    
    public constructor(name: string);
    begin
      self._name := name;
      self.def_is_set := false;
    end;
    public constructor(name: string; def: T);
    begin
      self.name := name;
      self.def := def;
      self.def_is_set := true;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public property Name: string read _name write _name;
    public property DefaultDefined: boolean read def_is_set;
    
    private function GetDefault: T;
    begin
      if not def_is_set then
        raise new InvalidOperationException($'%Err:Parameter:UnSet%');
      Result := self.def;
    end;
    public property &Default: T read def write
    begin
      self.def := value;
      self.def_is_set := true;
    end;
    
    public function NewSetter(val: T): ParameterQueueSetter;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += '["';
      sb += Name;
      sb += '"]: Default=';
      ToStringRuntimeValue(sb, self.def);
      sb += #10;
    end;
    
  end;
  
  {$endregion Parameter}
  
  {$region Cast}
  
  CommandQueueBase = abstract partial class
    
    public function Cast<T>: CommandQueue<T>;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    public function Cast<T>: CommandQueue<T>; where T: class;
    
  end;
  
  CommandQueue<T> = abstract partial class(CommandQueueBase) end;
  
  {$endregion Cast}
  
  {$region DiscardResult}
  
  CommandQueueBase = abstract partial class
    
    private function DiscardResultBase: CommandQueueNil; abstract;
    public function DiscardResult := DiscardResultBase;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    private function DiscardResultBase: CommandQueueNil; override := DiscardResult;
    public function DiscardResult := self;
    
  end;
  
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    private function DiscardResultBase: CommandQueueNil; override := DiscardResult;
    public function DiscardResult: CommandQueueNil;
    
  end;
  
  {$endregion DiscardResult}
  
  {$region ThenConvert}
  
  CommandQueueBase = abstract partial class
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase) end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    public function ThenConvert<TOtp>(f: T->TOtp): CommandQueue<TOtp>;
    public function ThenConvert<TOtp>(f: (T, Context)->TOtp): CommandQueue<TOtp>;
    
    public function ThenUse(p: T->()           ): CommandQueue<T>;
    public function ThenUse(p: (T, Context)->()): CommandQueue<T>;
    
    public function ThenQuickConvert<TOtp>(f: T->TOtp): CommandQueue<TOtp>;
    public function ThenQuickConvert<TOtp>(f: (T, Context)->TOtp): CommandQueue<TOtp>;
    
    public function ThenQuickUse(p: T->()           ): CommandQueue<T>;
    public function ThenQuickUse(p: (T, Context)->()): CommandQueue<T>;
    
  end;
  
  {$endregion ThenConvert}
  
  {$region +/*}
  
  CommandQueueBase = abstract partial class
    
    private function  AfterQueueSyncBase(q: CommandQueueBase): CommandQueueBase; abstract;
    private function AfterQueueAsyncBase(q: CommandQueueBase): CommandQueueBase; abstract;
    
    public static function operator+(q1, q2: CommandQueueBase): CommandQueueBase := q2.AfterQueueSyncBase(q1);
    public static function operator*(q1, q2: CommandQueueBase): CommandQueueBase := q2.AfterQueueAsyncBase(q1);
    
    public static procedure operator+=(var q1: CommandQueueBase; q2: CommandQueueBase) := q1 := q1+q2;
    public static procedure operator*=(var q1: CommandQueueBase; q2: CommandQueueBase) := q1 := q1*q2;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    private function  AfterQueueSyncBase(q: CommandQueueBase): CommandQueueBase; override := q+self;
    private function AfterQueueAsyncBase(q: CommandQueueBase): CommandQueueBase; override := q*self;
    
    public static function operator+(q1: CommandQueueBase; q2: CommandQueueNil): CommandQueueNil;
    public static function operator*(q1: CommandQueueBase; q2: CommandQueueNil): CommandQueueNil;
    
    public static procedure operator+=(var q1: CommandQueueNil; q2: CommandQueueNil) := q1 := q1+q2;
    public static procedure operator*=(var q1: CommandQueueNil; q2: CommandQueueNil) := q1 := q1*q2;
    
  end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    private function AfterQueueSyncBase (q: CommandQueueBase): CommandQueueBase; override := q+self;
    private function AfterQueueAsyncBase(q: CommandQueueBase): CommandQueueBase; override := q*self;
    
    public static function operator+(q1: CommandQueueBase; q2: CommandQueue<T>): CommandQueue<T>;
    public static function operator*(q1: CommandQueueBase; q2: CommandQueue<T>): CommandQueue<T>;
    
    public static procedure operator+=(var q1: CommandQueue<T>; q2: CommandQueue<T>) := q1 := q1+q2;
    public static procedure operator*=(var q1: CommandQueue<T>; q2: CommandQueue<T>) := q1 := q1*q2;
    
  end;
  
  {$endregion +/*}
  
  {$region Multiusable}
  
  CommandQueueBase = abstract partial class
    
    private function MultiusableBase: ()->CommandQueueBase; abstract;
    public function Multiusable := MultiusableBase;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    private function MultiusableBase: ()->CommandQueueBase; override := Multiusable() as object as Func<CommandQueueBase>; //TODO #2221
    public function Multiusable: ()->CommandQueueNil;
    
  end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    private function MultiusableBase: ()->CommandQueueBase; override := Multiusable() as object as Func<CommandQueueBase>; //TODO #2221
    public function Multiusable: ()->CommandQueue<T>;
    
  end;
  
  {$endregion Multiusable}
  
  {$region Finally+Handle}
  
  CommandQueueBase = abstract partial class
    
    private function AfterTry(try_do: CommandQueueBase): CommandQueueBase; abstract;
    public static function operator>=(try_do, do_finally: CommandQueueBase) := do_finally.AfterTry(try_do);
    
    private function ConvertErrHandler<TException>(handler: TException->boolean): Exception->boolean; where TException: Exception;
    begin Result := e->(e is TException) and handler(TException(e)) end;
    
    public function HandleWithoutRes<TException>(handler: TException->boolean): CommandQueueNil; where TException: Exception;
    begin Result := HandleWithoutRes(ConvertErrHandler(handler)) end;
    public function HandleWithoutRes(handler: Exception->boolean): CommandQueueNil;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    private function AfterTry(try_do: CommandQueueBase): CommandQueueBase; override := try_do >= self;
    public static function operator>=(try_do: CommandQueueBase; do_finally: CommandQueueNil): CommandQueueNil;
    
  end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    private function AfterTry(try_do: CommandQueueBase): CommandQueueBase; override := try_do >= self;
    public static function operator>=(try_do: CommandQueueBase; do_finally: CommandQueue<T>): CommandQueue<T>;
    
    public function HandleDefaultRes<TException>(handler: TException->boolean; def: T): CommandQueue<T>; where TException: Exception;
    begin Result := HandleDefaultRes(ConvertErrHandler(handler), def) end;
    public function HandleDefaultRes(handler: Exception->boolean; def: T): CommandQueue<T>;
    
    public function HandleReplaceRes(handler: List<Exception> -> T): CommandQueue<T>;
    
  end;
  
  {$endregion Finally+Handle}
  
  {$region Wait}
  
  WaitMarker = abstract partial class
    
    public static function Create: WaitMarker;
    
    public procedure SendSignal; abstract;
    
    public static function operator and(m1, m2: WaitMarker): WaitMarker;
    public static function operator or(m1, m2: WaitMarker): WaitMarker;
    
    private function ConvertToQBase: CommandQueueBase; abstract;
    public static function operator implicit(m: WaitMarker): CommandQueueBase := m.ConvertToQBase;
    
    {$region ToString}
    
    private function ToStringHeader(sb: StringBuilder; index: Dictionary<object,integer>): boolean;
    begin
      sb += DisplayName;
      
      var ind: integer;
      Result := not index.TryGetValue(self, ind);
      
      if Result then
      begin
        ind := index.Count;
        index[self] := ind;
      end;
      
      sb += '#';
      sb.Append(ind);
      
    end;
    private function DisplayName: string; virtual := CommandQueueBase.DisplayNameForType(self.GetType);
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); abstract;
    
    private procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>; write_tabs: boolean := true);
    begin
      if write_tabs then sb.Append(#9, tabs);
      ToStringHeader(sb, index);
      ToStringImpl(sb, tabs+1, index, delayed);
      
      if tabs=0 then foreach var q in delayed do
      begin
        sb += #10;
        q.ToString(sb, 0, index, new HashSet<CommandQueueBase>);
      end;
      
    end;
    
    public function ToString: string; override;
    begin
      var sb := new StringBuilder;
      ToString(sb, 0, new Dictionary<object, integer>, new HashSet<CommandQueueBase>);
      Result := sb.ToString;
    end;
    
    public function Print: WaitMarker;
    begin
      Write(self.ToString);
      Result := self;
    end;
    public function Println: WaitMarker;
    begin
      Writeln(self.ToString);
      Result := self;
    end;
    
    {$endregion ToString}
    
  end;
  
  DetachedMarkerSignalNil = sealed partial class
    
    private function get_signal_in_finally: boolean;
    public property SignalInFinally: boolean read get_signal_in_finally;
    
    public constructor(q: CommandQueueNil; signal_in_finally: boolean);
    private constructor := raise new OpenCLABCInternalException;
    
    public static function operator implicit(dms: DetachedMarkerSignalNil): WaitMarker;
    
    public procedure SendSignal := WaitMarker(self).SendSignal;
    public static function operator and(m1, m2: DetachedMarkerSignalNil) := WaitMarker(m1) and WaitMarker(m2);
    public static function operator or(m1, m2: DetachedMarkerSignalNil) := WaitMarker(m1) or WaitMarker(m2);
    
  end;
  DetachedMarkerSignal<T> = sealed partial class
    
    private function get_signal_in_finally: boolean;
    public property SignalInFinally: boolean read get_signal_in_finally;
    
    public constructor(q: CommandQueue<T>; signal_in_finally: boolean);
    private constructor := raise new OpenCLABCInternalException;
    
    public static function operator implicit(dms: DetachedMarkerSignal<T>): WaitMarker;
    
    public procedure SendSignal := WaitMarker(self).SendSignal;
    public static function operator and(m1, m2: DetachedMarkerSignal<T>) := WaitMarker(m1) and WaitMarker(m2);
    public static function operator or(m1, m2: DetachedMarkerSignal<T>) := WaitMarker(m1) or WaitMarker(m2);
    
  end;
  
  CommandQueueBase = abstract partial class end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
    public function ThenMarkerSignal := new DetachedMarkerSignalNil(self, false);
    public function ThenFinallyMarkerSignal := new DetachedMarkerSignalNil(self, true);
    
  end;
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    public function ThenMarkerSignal := new DetachedMarkerSignal<T>(self, false);
    public function ThenFinallyMarkerSignal := new DetachedMarkerSignal<T>(self, true);
    
    public function ThenWaitFor(marker: WaitMarker): CommandQueue<T>;
    public function ThenFinallyWaitFor(marker: WaitMarker): CommandQueue<T>;
    
  end;
  
  {$endregion Wait}
  
  {$endregion CommandQueue}
  
  {$region CLTask}
  
  CLTaskBase = abstract partial class
    private org_c: Context;
    private wh := new ManualResetEvent(false);
    private err_lst: List<Exception>;
    
    private function OrgQueueBase: CommandQueueBase; abstract;
    public property OrgQueue: CommandQueueBase read OrgQueueBase;
    
    public property OrgContext: Context read org_c;
    
    public procedure Wait;
    begin
      wh.WaitOne;
      if err_lst.Count=0 then exit;
      raise new AggregateException($'%Err:CLTask:%', err_lst.ToArray);
    end;
    
  end;
  
  CLTaskNil = sealed partial class(CLTaskBase)
    private q: CommandQueueNil;
    
    private constructor := raise new OpenCLABCInternalException;
    
    public property OrgQueue: CommandQueueNil read q; reintroduce;
    private function OrgQueueBase: CommandQueueBase; override := self.OrgQueue;
    
  end;
  
  CLTask<T> = sealed partial class(CLTaskBase)
    private q: CommandQueue<T>;
    
    private constructor := raise new OpenCLABCInternalException;
    
    public property OrgQueue: CommandQueue<T> read q; reintroduce;
    private function OrgQueueBase: CommandQueueBase; override := self.OrgQueue;
    
    public function WaitRes: T;
    
  end;
  
  Context = partial class
    
    public function BeginInvoke(q: CommandQueueBase; params parameters: array of ParameterQueueSetter): CLTaskBase;
    public function BeginInvoke(q: CommandQueueNil; params parameters: array of ParameterQueueSetter): CLTaskNil;
    public function BeginInvoke<T>(q: CommandQueue<T>; params parameters: array of ParameterQueueSetter): CLTask<T>;
    
    public procedure SyncInvoke(q: CommandQueueBase; params parameters: array of ParameterQueueSetter) := BeginInvoke(q, parameters).Wait;
    public procedure SyncInvoke(q: CommandQueueNil; params parameters: array of ParameterQueueSetter) := BeginInvoke(q, parameters).Wait;
    public function SyncInvoke<T>(q: CommandQueue<T>; params parameters: array of ParameterQueueSetter) := BeginInvoke(q, parameters).WaitRes;
    
  end;
  
  {$endregion CLTask}
  
  {$region KernelArg}
  
  KernelArg = abstract partial class
    
    {$region MemorySegment}
    
    public static function FromMemorySegment(mem: MemorySegment): KernelArg;
    public static function operator implicit(mem: MemorySegment): KernelArg := FromMemorySegment(mem);
    
    public static function FromMemorySegmentCQ(mem_q: CommandQueue<MemorySegment>): KernelArg;
    public static function operator implicit(mem_q: CommandQueue<MemorySegment>): KernelArg := FromMemorySegmentCQ(mem_q);
    public static function operator implicit(mem_q: ConstQueue<MemorySegment>): KernelArg := FromMemorySegmentCQ(mem_q);
    public static function operator implicit(mem_q: ParameterQueue<MemorySegment>): KernelArg := FromMemorySegmentCQ(mem_q);
    
    {$endregion MemorySegment}
    
    {$region CLArray}
    
    public static function FromCLArray<T>(a: CLArray<T>): KernelArg; where T: record;
    public static function operator implicit<T>(a: CLArray<T>): KernelArg; where T: record; begin Result := FromCLArray(a); end;
    
    public static function FromCLArrayCQ<T>(a_q: CommandQueue<CLArray<T>>): KernelArg; where T: record;
    public static function operator implicit<T>(a_q: CommandQueue<CLArray<T>>): KernelArg; where T: record; begin Result := FromCLArrayCQ(a_q); end;
    public static function operator implicit<T>(a_q: ConstQueue<CLArray<T>>): KernelArg; where T: record; begin Result := FromCLArrayCQ(a_q); end;
    public static function operator implicit<T>(a_q: ParameterQueue<CLArray<T>>): KernelArg; where T: record; begin Result := FromCLArrayCQ(a_q); end;
    
    {$endregion CLArray}
    
    {$region Data}
    
    public static function FromData(ptr: IntPtr; sz: UIntPtr): KernelArg;
    
    public static function FromDataCQ(ptr_q: CommandQueue<IntPtr>; sz_q: CommandQueue<UIntPtr>): KernelArg;
    
    public static function FromValueData<TRecord>(ptr: ^TRecord): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(ptr: ^TRecord): KernelArg; where TRecord: record; begin Result := FromValueData(ptr); end;
    
    {$endregion Data}
    
    {$region Value}
    
    public static function FromValue<TRecord>(val: TRecord): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(val: TRecord): KernelArg; where TRecord: record; begin Result := FromValue(val); end;
    
    public static function FromValueCQ<TRecord>(valq: CommandQueue<TRecord>): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(valq: CommandQueue<TRecord>): KernelArg; where TRecord: record; begin Result := FromValueCQ(valq); end;
    public static function operator implicit<TRecord>(valq: ConstQueue<TRecord>): KernelArg; where TRecord: record; begin Result := FromValueCQ(valq); end;
    public static function operator implicit<TRecord>(valq: ParameterQueue<TRecord>): KernelArg; where TRecord: record; begin Result := FromValueCQ(valq); end;
    
    {$endregion Value}
    
    {$region NativeValue}
    
    public static function FromNativeValue<TRecord>(val: NativeValue<TRecord>): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(val: NativeValue<TRecord>): KernelArg; where TRecord: record; begin Result := FromNativeValue(val); end;
    
    public static function FromNativeValueCQ<TRecord>(valq: CommandQueue<NativeValue<TRecord>>): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(valq: CommandQueue<NativeValue<TRecord>>): KernelArg; where TRecord: record; begin Result := FromNativeValueCQ(valq); end;
    public static function operator implicit<TRecord>(valq: ConstQueue<NativeValue<TRecord>>): KernelArg; where TRecord: record; begin Result := FromNativeValueCQ(valq); end;
    public static function operator implicit<TRecord>(valq: ParameterQueue<NativeValue<TRecord>>): KernelArg; where TRecord: record; begin Result := FromNativeValueCQ(valq); end;
    
    {$endregion NativeValue}
    
    {$region Array}
    
    public static function FromArray<TRecord>(a: array of TRecord; ind: integer := 0): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(a: array of TRecord): KernelArg; where TRecord: record; begin Result := FromArray(a); end;
    
    public static function FromArrayCQ<TRecord>(a_q: CommandQueue<array of TRecord>; ind_q: CommandQueue<integer> := 0): KernelArg; where TRecord: record;
    public static function operator implicit<TRecord>(a_q: CommandQueue<array of TRecord>): KernelArg; where TRecord: record; begin Result := FromArrayCQ(a_q); end;
    public static function operator implicit<TRecord>(a_q: ConstQueue<array of TRecord>): KernelArg; where TRecord: record; begin Result := FromArrayCQ(a_q); end;
    public static function operator implicit<TRecord>(a_q: ParameterQueue<array of TRecord>): KernelArg; where TRecord: record; begin Result := FromArrayCQ(a_q); end;
    
    {$endregion Array}
    
    {$region ToString}
    
    private function DisplayName: string; virtual := CommandQueueBase.DisplayNameForType(self.GetType);
    private static procedure ToStringRuntimeValue<T>(sb: StringBuilder; val: T) := CommandQueueBase.ToStringRuntimeValue(sb, val);
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); abstract;
    
    private procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>; write_tabs: boolean := true);
    begin
      if write_tabs then sb.Append(#9, tabs);
      sb += DisplayName;
      
      ToStringImpl(sb, tabs+1, index, delayed);
      
      if tabs=0 then foreach var q in delayed do
      begin
        sb += #10;
        q.ToString(sb, 0, index, new HashSet<CommandQueueBase>);
      end;
      
    end;
    
    public function ToString: string; override;
    begin
      var sb := new StringBuilder;
      ToString(sb, 0, new Dictionary<object, integer>, new HashSet<CommandQueueBase>);
      Result := sb.ToString;
    end;
    
    public function Print: KernelArg;
    begin
      Write(self.ToString);
      Result := self;
    end;
    public function Println: KernelArg;
    begin
      Writeln(self.ToString);
      Result := self;
    end;
    
    {$endregion ToString}
    
  end;
  
  {$endregion KernelArg}
  
  {$region KernelCCQ}
  
  KernelCCQ = sealed partial class
    
    {%ContainerCommon\Kernel\Interface!ContainerCommon.pas%}
    
    {%ContainerMethods\Kernel\Explicit.Interface!ContainerMethods.pas%}
    
  end;
  
  Kernel = partial class
    public function NewQueue := new KernelCCQ({%>self%});
  end;
  
  {$endregion KernelCCQ}
  
  {$region MemorySegmentCCQ}
  
  MemorySegmentCCQ = sealed partial class
    
    {%ContainerCommon\MemorySegment\Interface!ContainerCommon.pas%}
    
    {%ContainerMethods\MemorySegment\Explicit.Interface!ContainerMethods.pas%}
    
    {%ContainerMethods\MemorySegment.Get\Explicit.Interface!ContainerGetMethods.pas%}
    
  end;
  
  MemorySegment = partial class
    public function NewQueue := new MemorySegmentCCQ({%>self%});
  end;
  
  KernelArg = abstract partial class
    public static function operator implicit(mem_q: MemorySegmentCCQ): KernelArg;
  end;
  
  {$endregion MemorySegmentCCQ}
  
  {$region CLArrayCCQ}
  
  CLArrayCCQ<T> = sealed partial class
  where T: record;
    
    {%ContainerCommon\CLArray\Interface!ContainerCommon.pas%}
    
    {%ContainerMethods\CLArray\Explicit.Interface!ContainerMethods.pas%}
    
    {%ContainerMethods\CLArray.Get\Explicit.Interface!ContainerGetMethods.pas%}
    
  end;
  
  CLArray<T> = partial class
    public function NewQueue := new CLArrayCCQ<T>({%>self%});
  end;
  
  KernelArg = abstract partial class
    public static function operator implicit<T>(a_q: CLArrayCCQ<T>): KernelArg; where T: record;
  end;
  
  {$endregion CLArrayCCQ}
  
{$region Global subprograms}

{$region ConstQueue}

function CQ<T>(o: T): CommandQueue<T>;

{$endregion ConstQueue}

{$region HFQ/HPQ}

function HFQ<T>(f: ()->T): CommandQueue<T>;
function HFQ<T>(f: Context->T): CommandQueue<T>;
function HFQQ<T>(f: ()->T): CommandQueue<T>;
function HFQQ<T>(f: Context->T): CommandQueue<T>;

function HPQ(p: ()->()): CommandQueueNil;
function HPQ(p: Context->()): CommandQueueNil;
function HPQQ(p: ()->()): CommandQueueNil;
function HPQQ(p: Context->()): CommandQueueNil;

{$endregion HFQ/HPQ}

{$region Wait}

function WaitAll(params sub_markers: array of WaitMarker): WaitMarker;
function WaitAll(sub_markers: sequence of WaitMarker): WaitMarker;

function WaitAny(params sub_markers: array of WaitMarker): WaitMarker;
function WaitAny(sub_markers: sequence of WaitMarker): WaitMarker;

function WaitFor(marker: WaitMarker): CommandQueueNil;

{$endregion Wait}

{$region CombineQueue's}

{%CombineQueues\Interface!CombineQueues.pas%}

{$endregion CombineQueue's}

{$endregion Global subprograms}

implementation

{$region Properties}

{$region Base}

type
  NtvPropertiesBase<TNtv, TInfo> = abstract class
    protected ntv: TNtv;
    public constructor(ntv: TNtv) := self.ntv := ntv;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure GetSizeImpl(id: TInfo; var sz: UIntPtr); abstract;
    protected procedure GetValImpl(id: TInfo; sz: UIntPtr; var res: byte); abstract;
    
    protected function GetSize(id: TInfo): UIntPtr;
    begin GetSizeImpl(id, Result); end;
    
    protected procedure FillPtr(id: TInfo; sz: UIntPtr; ptr: IntPtr) :=
    GetValImpl(id, sz, PByte(pointer(ptr))^);
    protected procedure FillVal<T>(id: TInfo; sz: UIntPtr; var res: T) :=
    GetValImpl(id, sz, PByte(pointer(@res))^);
    
    protected function GetVal<T>(id: TInfo): T;
    begin FillVal(id, new UIntPtr(Marshal.SizeOf&<T>), Result); end;
    protected function GetValArr<T>(id: TInfo): array of T;
    begin
      var sz := GetSize(id);
      Result := new T[uint64(sz) div Marshal.SizeOf&<T>];
      
      if Result.Length<>0 then
        FillVal(id, sz, Result[0]);
      
    end;
//    protected function GetValArrArr<T>(id: TInfo; szs: array of UIntPtr): array of array of T;
//    type PT = ^T;
//    begin
//      if szs.Length=0 then
//      begin
//        SetLength(Result,0);
//        exit;
//      end;
//      
//      var res := new IntPtr[szs.Length];
//      SetLength(Result, szs.Length);
//      
//      for var i := 0 to szs.Length-1 do res[i] := Marshal.AllocHGlobal(IntPtr(pointer(szs[i])));
//      try
//        
//        FillVal(id, new UIntPtr(szs.Length*Marshal.SizeOf&<IntPtr>), res[0]);
//        
//        var tsz := Marshal.SizeOf&<T>;
//        for var i := 0 to szs.Length-1 do
//        begin
//          Result[i] := new T[uint64(szs[i]) div tsz];
//          //To Do более эффективное копирование
//          for var i2 := 0 to Result[i].Length-1 do
//            Result[i][i2] := PT(pointer(res[i]+tsz*i2))^;
//        end;
//        
//      finally
//        for var i := 0 to szs.Length-1 do Marshal.FreeHGlobal(res[i]);
//      end;
//      
//    end;
    
    private function GetString(id: TInfo): string;
    begin
      var sz := GetSize(id);
      
      var str_ptr := Marshal.AllocHGlobal(IntPtr(pointer(sz)));
      try
        FillPtr(id, sz, str_ptr);
        Result := Marshal.PtrToStringAnsi(str_ptr);
      finally
        Marshal.FreeHGlobal(str_ptr);
      end;
      
    end;
    
  end;
  
{$endregion Base}

{%WrapperProperties\Implementation!WrapperProperties.pas%}

{$endregion Properties}

{$region Wrappers}

{$region Device}

static function Device.FromNative(ntv: cl_device_id): Device;
begin
  
  var parent: cl_device_id;
  OpenCLABCInternalException.RaiseIfError(
    cl.GetDeviceInfo(ntv, DeviceInfo.DEVICE_PARENT_DEVICE, new UIntPtr(cl_device_id.Size), parent, IntPtr.Zero)
  );
  
  if parent=cl_device_id.Zero then
    Result := new Device(ntv) else
    Result := new SubDevice(parent, ntv);
  
end;

{$endregion Device}

{$region MemorySegment}

static function MemorySegment.FromNative(ntv: cl_mem): MemorySegment;
begin
  var t: MemObjectType;
  OpenCLABCInternalException.RaiseIfError(
    cl.GetMemObjectInfo(ntv, MemInfo.MEM_TYPE, new UIntPtr(sizeof(MemObjectType)), t, IntPtr.Zero)
  );
  
  if t<>MemObjectType.MEM_OBJECT_BUFFER then
    raise new ArgumentException($'%Err:MemorySegment:WrongNtvType%');
  
  var parent: cl_mem;
  OpenCLABCInternalException.RaiseIfError(
    cl.GetMemObjectInfo(ntv, MemInfo.MEM_ASSOCIATED_MEMOBJECT, new UIntPtr(cl_mem.Size), parent, IntPtr.Zero)
  );
  
  if parent=cl_mem.Zero then
  begin
    Result := new MemorySegment(ntv);
    GC.AddMemoryPressure(Result.Size64);
  end else
    Result := new MemorySubSegment(parent, ntv);
  
end;

{$endregion MemorySegment}

{$region CLArray}

function CLArray<T>.GetItemProp(ind: integer): T :=
{%>GetValue(ind)!!} default(T) {%};
procedure CLArray<T>.SetItemProp(ind: integer; value: T) :=
{%>WriteValue(value, ind)!!} exit() {%};

function CLArray<T>.GetSectionProp(range: IntRange): array of T :=
{%>GetArray(range.Low, range.High-range.Low+1)!!} nil {%};
procedure CLArray<T>.SetSectionProp(range: IntRange; value: array of T) :=
{%>WriteArray(value, range.Low, range.High-range.Low+1, 0)!!} exit() {%};

{$endregion CLArray}

{$endregion Wrappers}

{$region Util type's}

{$region Blittable}

type
  BlittableException = sealed class(Exception)
    public constructor(t, blame: System.Type; source_name: string) :=
    inherited Create(t=blame ? $'%Err:Blittable:Main%' : $'%Err:Blittable:Blame%' );
  end;
  BlittableHelper = static class
    
    private static blittable_cache := new Dictionary<System.Type, System.Type>;
    public static function Blame(t: System.Type): System.Type;
    begin
      if t.IsPointer then exit;
      if t.IsClass then
      begin
        Result := t;
        exit;
      end;
      
      foreach var fld in t.GetFields(System.Reflection.BindingFlags.Instance or System.Reflection.BindingFlags.Public or System.Reflection.BindingFlags.NonPublic) do
        if fld.FieldType<>t then
        begin
          Result := Blame(fld.FieldType);
          if Result<>nil then break;
        end;
      
      if Result=nil then
      begin
        var o := System.Activator.CreateInstance(t);
        try
          GCHandle.Alloc(o, GCHandleType.Pinned).Free;
        except
          on System.ArgumentException do
            Result := t;
        end;
      end;
      
      blittable_cache[t] := Result;
    end;
    
    public static procedure RaiseIfBad(t: System.Type; source_name: string);
    begin
      var blame := BlittableHelper.Blame(t);
      if blame=nil then exit;
      raise new BlittableException(t, blame, source_name);
    end;
    
  end;
  
  NativeValue<T> = partial class
    static constructor :=
    BlittableHelper.RaiseIfBad(typeof(T), '%Err:Blittable:Source:CLArray%');
  end;
  
  CLArray<T> = partial class
    static constructor :=
    BlittableHelper.RaiseIfBad(typeof(T), '%Err:Blittable:Source:CLArray%');
  end;
  
{$endregion Blittable}

{$region InterlockedBoolean}

type
  InterlockedBoolean = record
    private val := 0;
    
    public function TrySet(b: boolean): boolean;
    begin
      var prev := integer(not b);
      var curr := integer(b);
      Result := Interlocked.CompareExchange(val, curr, prev)=prev;
    end;
    
    public static function operator implicit(b: InterlockedBoolean): boolean := b.val<>0;
    
  end;
  
{$endregion InterlockedBoolean}

{$region NativeUtils}

type
  NativeUtils = static class
    
    public static function AsPtr<T>(p: pointer): ^T := p;
    public static function AsPtr<T>(p: IntPtr) := AsPtr&<T>(pointer(p));
    
    public static function CopyToUnm<TRecord>(a: TRecord): IntPtr; where TRecord: record;
    begin
      Result := Marshal.AllocHGlobal(Marshal.SizeOf&<TRecord>);
      AsPtr&<TRecord>(Result)^ := a;
    end;
    
    public static function StartNewBgThread(p: Action): Thread;
    begin
      Result := new Thread(p);
      Result.IsBackground := true;
      Result.Start;
    end;
    
  end;
  
{$endregion NativeUtils}

{$region CLTaskErrHandler}

type
  CLTaskErrHandler = abstract class
    private local_err_lst := new List<Exception>;
    
    {$region AddErr}
    
    protected procedure AddErr(e: Exception);
    begin
      if e is OpenCLABCInternalException then
        // Внутренние ошибки не регестрируем
        System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(e).Throw;
      // HPQ(()->exit()) + HPQ(()->raise)
      // Тут сначала вычисляет HadError как false, а затем переключает на true
      had_error_cache := true;
      local_err_lst += e;
    end;
    
    {$endregion AddErr}
    
    function get_local_err_lst: List<Exception>;
    begin
      had_error_cache := nil;
      Result := local_err_lst;
    end;
    
    private had_error_cache := default(boolean?);
    protected function HadErrorInPrev(can_cache: boolean): boolean; abstract;
    public function HadError(can_cache: boolean): boolean;
    begin
      if had_error_cache<>nil then
      begin
        Result := had_error_cache.Value;
        exit;
      end;
      Result := (local_err_lst.Count<>0) or HadErrorInPrev(can_cache);
      if can_cache then had_error_cache := Result;
    end;
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; abstract;
    protected function TryRemoveErrors(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean;
    begin
      Result := false;
      if had_error_cache=false then exit;
      
      Result := TryRemoveErrorsInPrev(origin_cache, handler);
      
      Result := (local_err_lst.RemoveAll(handler)<>0) or Result;
      if Result then had_error_cache := nil;
    end;
    public procedure TryRemoveErrors(handler: Exception->boolean) :=
    TryRemoveErrors(new Dictionary<CLTaskErrHandler, boolean>, handler);
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); abstract;
    protected procedure FillErrLst(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>);
    begin
      {$ifndef DEBUG}
      if not HadError(true) then exit;
      {$endif DEBUG}
      
      FillErrLstWithPrev(origin_cache, lst);
      
      lst.AddRange(local_err_lst);
    end;
    public procedure FillErrLst(lst: List<Exception>) :=
    FillErrLst(new HashSet<CLTaskErrHandler>, lst);
    
    public procedure SanityCheck(err_lst: List<Exception>);
    begin
      
      // QErr*QErr - second cache wouldn't be calculated
//      if had_error_cache=nil then
//        raise new OpenCLABCInternalException($'SanityCheck expects all had_error_cache to exist');
      
      begin
        var had_error := self.HadError(true);
        if had_error <> (err_lst.Count<>0) then
          raise new OpenCLABCInternalException($'{had_error} <> {err_lst.Count}');
      end;
      
      // In case "A + B*C" handler of C would see error in A, but ignore it in FillErrLst
//      if prev_action <> EPA_Ignore then
//        foreach var h in prev do
//          h.SanityCheck;
      
    end;
//    public procedure SanityCheck;
//    begin
//      var err_lst := new List<Exception>;
//      FillErrLst(err_lst);
//      SanityCheck(err_lst);
//    end;
    
  end;
  
  CLTaskErrHandlerEmpty = sealed class(CLTaskErrHandler)
    
    public constructor := exit;
    
    protected function HadErrorInPrev(can_cache: boolean): boolean; override := false;
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; override := false;
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); override := exit;
    
  end;
  
  CLTaskErrHandlerSimpleRepeater = sealed class(CLTaskErrHandler)
    private prev: CLTaskErrHandler;
    
    public constructor(prev: CLTaskErrHandler) := self.prev := prev;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function HadErrorInPrev(can_cache: boolean): boolean; override := prev.HadError(can_cache);
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; override := prev.TryRemoveErrors(origin_cache, handler);
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); override := prev.FillErrLst(origin_cache, lst);
    
  end;
  
  CLTaskErrHandlerBranchBase = sealed class(CLTaskErrHandler)
    private origin: CLTaskErrHandler;
    
    public constructor(origin: CLTaskErrHandler) := self.origin := origin;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function HadErrorInPrev(can_cache: boolean): boolean; override := origin.HadError(can_cache);
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; override;
    begin
      if origin_cache.TryGetValue(origin, Result) then exit;
      // Can't remove from here, because "A + B*C.Handle" would otherwise consume error in A
      // Instead CLTaskErrHandlerBranchCombinator handles origin
//      Result := origin.TryRemoveErrors(origin_cache, handler);
    end;
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); override;
    begin
      if origin_cache.Contains(origin) then exit;
      origin.FillErrLst(origin_cache, lst);
    end;
    
  end;
  CLTaskErrHandlerBranchCombinator = sealed class(CLTaskErrHandler)
    private origin: CLTaskErrHandler;
    private branches: array of CLTaskErrHandler;
    
    public constructor(origin: CLTaskErrHandler; branches: array of CLTaskErrHandler);
    begin
      self.origin := origin;
      self.branches := branches;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function HadErrorInPrev(can_cache: boolean): boolean; override;
    begin
      Result := origin.HadError(can_cache);
      if Result then exit;
      foreach var h in branches do
      begin
        Result := h.HadError(can_cache);
        if Result then exit;
      end;
    end;
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; override;
    begin
      Result := origin.TryRemoveErrors(origin_cache, handler);
      origin_cache.Add(origin, Result);
      foreach var h in branches do
        Result := h.TryRemoveErrors(origin_cache, handler) or Result;
      origin_cache.Remove(origin);
    end;
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); override;
    begin
      origin.FillErrLst(origin_cache, lst);
      {$ifdef DEBUG}if not{$endif}origin_cache.Add(origin)
      {$ifdef DEBUG}then
        raise new OpenCLABCInternalException($'Origin added multiple times');
      {$endif DEBUG};
      foreach var h in branches do
        h.FillErrLst(origin_cache, lst);
      origin_cache.Remove(origin);
    end;
    
  end;
  
  CLTaskErrHandlerThiefBase = abstract class(CLTaskErrHandler)
    protected victim: CLTaskErrHandler;
    
    public constructor(victim: CLTaskErrHandler) := self.victim := victim;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function CanSteal: boolean; abstract;
    public procedure StealPrevErrors;
    begin
      if victim=nil then exit;
      if CanSteal then
        victim.FillErrLst(self.local_err_lst);
      victim := nil;
    end;
    
    protected function HadErrorInVictim(can_cache: boolean): boolean :=
    (victim<>nil) and victim.HadError(can_cache);
    
  end;
  CLTaskErrHandlerThief = sealed class(CLTaskErrHandlerThiefBase)
    
    protected function CanSteal: boolean; override := true;
    
    protected function HadErrorInPrev(can_cache: boolean): boolean; override := HadErrorInVictim(can_cache);
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; override;
    begin
      StealPrevErrors;
      Result := false;
    end;
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); override;
    begin
      StealPrevErrors;
    end;
    
  end;
  /// Repeats first handler, but also steals errors from second, if first is OK
  CLTaskErrHandlerThiefRepeater = sealed class(CLTaskErrHandlerThiefBase)
    private prev_handler: CLTaskErrHandler;
    
    public constructor(prev_handler, victim: CLTaskErrHandler);
    begin
      inherited Create(victim);
      self.prev_handler := prev_handler;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function CanSteal: boolean; override :=
    not prev_handler.HadError(true);
    
    protected function HadErrorInPrev(can_cache: boolean): boolean; override :=
    // mu_handler.HadError would be called more often,
    // so it's more likely to already have cache
    HadErrorInVictim(can_cache) or prev_handler.HadError(can_cache);
    
    protected function TryRemoveErrorsInPrev(origin_cache: Dictionary<CLTaskErrHandler, boolean>; handler: Exception->boolean): boolean; override;
    begin
      Result := prev_handler.TryRemoveErrors(origin_cache, handler);
      if CanSteal then StealPrevErrors;
    end;
    
    protected procedure FillErrLstWithPrev(origin_cache: HashSet<CLTaskErrHandler>; lst: List<Exception>); override;
    begin
      var prev_c := lst.Count;
      prev_handler.FillErrLst(lst);
      if prev_c=lst.Count then StealPrevErrors;
    end;
    
  end;
  
{$endregion CLTaskErrHandler}

{$region EventList}

type
  AttachCallbackData = sealed class
    public work: Action;
    {$ifdef EventDebug}
    public reason: string;
    {$endif EventDebug}
    
    public constructor(work: Action{$ifdef EventDebug}; reason: string{$endif});
    begin
      self.work := work;
      {$ifdef EventDebug}
      self.reason := reason;
      {$endif EventDebug}
    end;
    private constructor := raise new OpenCLABCInternalException;
    
  end;
  
  MultiAttachCallbackData = sealed class
    public work: Action;
    public left_c: integer;
    {$ifdef EventDebug}
    public reason: string;
    public all_evs: sequence of cl_event;
    {$endif EventDebug}
    
    public constructor(work: Action; left_c: integer{$ifdef EventDebug}; reason: string; all_evs: sequence of cl_event{$endif});
    begin
      self.work := work;
      self.left_c := left_c;
      {$ifdef EventDebug}
      self.reason := reason;
      self.all_evs := all_evs;
      {$endif EventDebug}
    end;
    private constructor := raise new OpenCLABCInternalException;
    
  end;
  
  EventList = record
    public evs: array of cl_event;
    public count := 0;
    
    {$region Misc}
    
    public property Item[i: integer]: cl_event read evs[i]; default;
    
    public static function operator=(l1, l2: EventList): boolean;
    begin
      Result := false;
      if object.ReferenceEquals(l1, l2) then
      begin
        Result := true;
        exit;
      end;
      if object.ReferenceEquals(l1, nil) then exit;
      if object.ReferenceEquals(l2, nil) then exit;
      if l1.count <> l2.count then exit;
      for var i := 0 to l1.count-1 do
        if l1[i]<>l2[i] then exit;
      Result := true;
    end;
    public static function operator<>(l1, l2: EventList): boolean := not (l1=l2);
    
    {$endregion Misc}
    
    {$region constructor's}
    
    public constructor(count: integer) :=
    self.evs := new cl_event[count];
    public constructor := raise new OpenCLABCInternalException;
    public static Empty := default(EventList);
    
    public static function operator implicit(ev: cl_event): EventList;
    begin
      if ev=cl_event.Zero then
        Result := Empty else
      begin
        Result := new EventList(1);
        Result += ev;
      end;
    end;
    
    public constructor(params evs: array of cl_event);
    begin
      self.evs := evs;
      self.count := evs.Length;
    end;
    
    {$endregion constructor's}
    
    {$region operator+}
    
    public static procedure operator+=(var l: EventList; ev: cl_event);
    begin
      l.evs[l.count] := ev;
      l.count += 1;
    end;
    
    public static procedure operator+=(var l: EventList; ev: EventList);
    begin
      for var i := 0 to ev.count-1 do
        l += ev[i];
    end;
    
    public static function operator+(l1, l2: EventList): EventList;
    begin
      Result := new EventList(l1.count+l2.count);
      Result += l1;
      Result += l2;
    end;
    
    public static function operator+(l: EventList; ev: cl_event): EventList;
    begin
      Result := new EventList(l.count+1);
      Result += l;
      Result += ev;
    end;
    
    private static function Combine<TList>(evs: TList): EventList; where TList: IList<EventList>;
    begin
      Result := EventList.Empty;
      var count := 0;
      
      //TODO #2589
      for var i := 0 to (evs as IList<EventList>).Count-1 do
        count += evs.Item[i].count;
      if count=0 then exit;
      
      Result := new EventList(count);
      //TODO #2589
      for var i := 0 to (evs as IList<EventList>).Count-1 do
        Result += evs.Item[i];
      
    end;
    
    {$endregion operator+}
    
    {$region AttachCallback}
    
    private static procedure CheckEvErr(ev: cl_event{$ifdef EventDebug}; reason: string{$endif});
    begin
      {$ifdef EventDebug}
      EventDebug.CheckExists(ev, reason);
      {$endif EventDebug}
      var st: CommandExecutionStatus;
      var ec := cl.GetEventInfo(ev, EventInfo.EVENT_COMMAND_EXECUTION_STATUS, new UIntPtr(sizeof(CommandExecutionStatus)), st, IntPtr.Zero);
      OpenCLABCInternalException.RaiseIfError(ec);
      OpenCLABCInternalException.RaiseIfError(st);
    end;
    
    private static procedure InvokeAttachedCallback(ev: cl_event; st: CommandExecutionStatus; data: IntPtr);
    begin
      var hnd := GCHandle(data);
      var cb_data := AttachCallbackData(hnd.Target);
      // st копирует значение переданное в cl.SetEventCallback, поэтому он не подходит
      CheckEvErr(ev{$ifdef EventDebug}, cb_data.reason{$endif});
      {$ifdef EventDebug}
      EventDebug.RegisterEventRelease(ev, $'released in callback, working on {cb_data.reason}');
      {$endif EventDebug}
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseEvent(ev) );
      hnd.Free;
      cb_data.work();
    end;
    private static attachable_callback: EventCallback := InvokeAttachedCallback;
    
    public static procedure AttachCallback(ev: cl_event; work: Action{$ifdef EventDebug}; reason: string{$endif});
    begin
      var cb_data := new AttachCallbackData(work{$ifdef EventDebug}, reason{$endif});
      var ec := cl.SetEventCallback(ev, CommandExecutionStatus.COMPLETE, attachable_callback, GCHandle.ToIntPtr(GCHandle.Alloc(cb_data)));
      OpenCLABCInternalException.RaiseIfError(ec);
    end;
    
    {$endregion AttachCallback}
    
    {$region MultiAttachCallback}
    
    private static procedure InvokeMultiAttachedCallback(ev: cl_event; st: CommandExecutionStatus; data: IntPtr);
    begin
      var hnd := GCHandle(data);
      var cb_data := MultiAttachCallbackData(hnd.Target);
      // st копирует значение переданное в cl.SetEventCallback, поэтому он не подходит
      CheckEvErr(ev{$ifdef EventDebug}, cb_data.reason{$endif});
      {$ifdef EventDebug}
      EventDebug.RegisterEventRelease(ev, $'released in multi-callback, working on {cb_data.reason}, together with evs: {cb_data.all_evs.JoinToString}');
      {$endif EventDebug}
      OpenCLABCInternalException.RaiseIfError(cl.ReleaseEvent(ev));
      if Interlocked.Decrement(cb_data.left_c) <> 0 then exit;
      hnd.Free;
      cb_data.work();
    end;
    private static multi_attachable_callback: EventCallback := InvokeMultiAttachedCallback;
    
    public procedure MultiAttachCallback(work: Action{$ifdef EventDebug}; reason: string{$endif}) :=
    case self.count of
      0: work;
      1: AttachCallback(self.evs[0], work{$ifdef EventDebug}, reason{$endif});
      else
      begin
        var cb_data := new MultiAttachCallbackData(work, self.count{$ifdef EventDebug}, reason, evs.Take(count){$endif});
        var hnd_ptr := GCHandle.ToIntPtr(GCHandle.Alloc(cb_data));
        for var i := 0 to count-1 do
        begin
          var ec := cl.SetEventCallback(evs[i], CommandExecutionStatus.COMPLETE, multi_attachable_callback, hnd_ptr);
          OpenCLABCInternalException.RaiseIfError(ec);
        end;
      end;
    end;
    
    {$endregion MultiAttachCallback}
    
    {$region Retain/Release}
    
    public procedure Retain({$ifdef EventDebug}reason: string{$endif}) :=
    for var i := 0 to count-1 do
    begin
      {$ifdef EventDebug}
      EventDebug.RegisterEventRetain(evs[i], $'{reason}, together with evs: {evs.Take(count).JoinToString}');
      {$endif EventDebug}
      OpenCLABCInternalException.RaiseIfError( cl.RetainEvent(evs[i]) );
    end;
    
    public procedure Release({$ifdef EventDebug}reason: string{$endif}) :=
    for var i := 0 to count-1 do
    begin
      {$ifdef EventDebug}
      EventDebug.RegisterEventRelease(evs[i], $'{reason}, together with evs: {evs.Take(count).JoinToString}');
      {$endif EventDebug}
      OpenCLABCInternalException.RaiseIfError( cl.ReleaseEvent(evs[i]) );
    end;
    
    // cl.WaitForEvents uses processor time to wait
    // so if we need to wait it's better to use ManualResetEvent
    public function ToMRE({$ifdef EventDebug}reason: string{$endif}): ManualResetEvent;
    begin
      Result := nil;
      if self.count=0 then exit;
      Result := new ManualResetEvent(false);
      var mre := Result;
      self.MultiAttachCallback(()->mre.Set(){$ifdef EventDebug}, $'setting mre for {reason}'{$endif});
    end;
    
    {$endregion Retain/Release}
    
  end;
  
{$endregion EventList}

{$region CLTaskGlobalData}

type
  IParameterQueue = interface
    
    property Name: string read;
    
  end;
  ParameterQueueSetter = sealed partial class
    par_q: IParameterQueue;
    
    public constructor(par_q: IParameterQueue; val: object);
    begin
      self.par_q := par_q;
      self.val := val;
    end;
    
    public property Name: string read par_q.Name;
    
  end;
  ParameterQueue<T> = sealed partial class(CommandQueue<T>, IParameterQueue)
    
  end;
  
//TODO #????
function ParameterQueue<T>.NewSetter(val: T) := new ParameterQueueSetter(self as object as IParameterQueue, val);

type
  CLTaskParameterData = record
    val: object;
    state: (TPS_Empty, TPS_Default, TPS_Set);
    
    public constructor :=
    self.state := TPS_Empty;
    public constructor(def: object);
    begin
      self.val := def;
      self.state := TPS_Default;
    end;
    
    public function &Set(name: string; val: object): CLTaskParameterData;
    begin
      if self.state=TPS_Set then
        raise new ArgumentException($'%Err:Parameter:SetAgain%');
      Result.val := val;
      Result.state := TPS_Set;
    end;
    
    public procedure TestSet(name: string) :=
    if self.state=TPS_Empty then
      raise new ArgumentException($'%Err:Parameter:UnSet%');
    
  end;
  
  CLTaskGlobalData = sealed partial class
    public tsk: CLTaskBase;
    
    public c: Context;
    public cl_c: cl_context;
    public cl_dvc: cl_device_id;
    
    private curr_inv_cq := cl_command_queue.Zero;
    private outer_cq := cl_command_queue.Zero;
    private free_cqs := new System.Collections.Concurrent.ConcurrentBag<cl_command_queue>;
    
    public curr_err_handler: CLTaskErrHandler := new CLTaskErrHandlerEmpty;
    
    private constructor := raise new OpenCLABCInternalException;
    
    public function GetCQ(async_enqueue: boolean := false): cl_command_queue;
    begin
      Result := curr_inv_cq;
      
      if Result=cl_command_queue.Zero then
      begin
        if outer_cq<>cl_command_queue.Zero then
        begin
          Result := outer_cq;
          outer_cq := cl_command_queue.Zero;
        end else
        if free_cqs.TryTake(Result) then
          else
        begin
          var ec: ErrorCode;
          Result := cl.CreateCommandQueue(cl_c, cl_dvc, CommandQueueProperties.NONE, ec);
          OpenCLABCInternalException.RaiseIfError(ec);
        end;
      end;
      
      curr_inv_cq := if async_enqueue then cl_command_queue.Zero else Result;
    end;
    
    public procedure ReturnCQ(cq: cl_command_queue);
    begin
      free_cqs.Add(cq);
      {$ifdef QueueDebug}
      QueueDebug.Add(cq, '----- return -----');
      {$endif QueueDebug}
    end;
    
    public parameters := new Dictionary<IParameterQueue, CLTaskParameterData>;
    public procedure ApplyParameters(pars: array of ParameterQueueSetter);
    begin
      foreach var par in pars do
      begin
        if not parameters.ContainsKey(par.par_q) then
          raise new ArgumentException($'%Err:Parameter:NotFound%');
        parameters[par.par_q] := parameters[par.par_q].Set(par.Name, par.val);
      end;
      foreach var kvp in self.parameters do
        kvp.Value.TestSet(kvp.Key.Name);
    end;
    
  end;
  
{$endregion CLTaskGlobalData}

{$region UserEvent}

type
  UserEvent = sealed class
    private uev: cl_event;
    private done := new InterlockedBoolean;
    
    {$region constructor's}
    
    private constructor(c: cl_context{$ifdef EventDebug}; reason: string{$endif});
    begin
      var ec: ErrorCode;
      self.uev := cl.CreateUserEvent(c, ec);
      OpenCLABCInternalException.RaiseIfError(ec);
      {$ifdef EventDebug}
      EventDebug.RegisterEventRetain(self.uev, $'Created for {reason}');
      {$endif EventDebug}
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public static function StartBackgroundWork(after: EventList; work: Action; c: cl_context{$ifdef EventDebug}; reason: string{$endif}): UserEvent;
    begin
      var res := new UserEvent(c
        {$ifdef EventDebug}, $'BackgroundWork, executing {reason}, after waiting on: {after.evs?.JoinToString}'{$endif}
      );
      
      var mre := after.ToMRE({$ifdef EventDebug}$'Background work with res_ev={res}'{$endif});
      NativeUtils.StartNewBgThread(()->
      begin
        if mre<>nil then mre.WaitOne;
        
        try
          work;
        finally
          res.SetComplete;
        end;
      end);
      
      Result := res;
    end;
    
    {$endregion constructor's}
    
    {$region Status}
    
    /// True если статус получилось изменить
    public function SetStatus(st: CommandExecutionStatus): boolean;
    begin
      Result := done.TrySet(true);
      if Result then OpenCLABCInternalException.RaiseIfError(
        cl.SetUserEventStatus(uev, st)
      );
    end;
    public function SetComplete := SetStatus(CommandExecutionStatus.COMPLETE);
    
    {$endregion Status}
    
    {$region operator's}
    
    public static function operator implicit(ev: UserEvent): cl_event := ev.uev;
    public static function operator implicit(ev: UserEvent): EventList := ev.uev;
    
    //TODO #????
//    public static function operator+(ev1: EventList; ev2: UserEvent): EventList;
//    begin
//      Result := ev1 + ev2.uev;
//      Result.abortable := true;
//    end;
//    public static procedure operator+=(ev1: EventList; ev2: UserEvent);
//    begin
//      ev1 += ev2.uev;
//      ev1.abortable := true;
//    end;
    
    public function ToString: string; override := $'UserEvent[{uev.val}]';
    
    {$endregion operator's}
    
  end;
  
{$endregion UserEvent}

{$region QueueResAction}

type
  QueueResAction = Context->();
  QueueResSetter<T> = Context->T;
  
  QueueResActionUtils = static class
    
    static function HandlerWrap(err_handler: CLTaskErrHandler; d: QueueResAction): QueueResAction := c->
    if not err_handler.HadError(true) then
    try
      d(c);
    except
      on e: Exception do err_handler.AddErr(e);
    end;
    static function HandlerWrap<T>(err_handler: CLTaskErrHandler; d: QueueResSetter<T>): QueueResSetter<T> := c->
    if not err_handler.HadError(true) then
    try
      Result := d(c);
    except
      on e: Exception do err_handler.AddErr(e);
    end;
    static function HandlerWrapStrip<T>(err_handler: CLTaskErrHandler; d: QueueResSetter<T>): QueueResAction := c->
    if not err_handler.HadError(true) then
    try
      d(c);
    except
      on e: Exception do err_handler.AddErr(e);
    end;
    
    static function HandlerWrap<T>(err_handler: CLTaskErrHandler; d: (T,Context)->()): (T,Context)->() := (o,c)->
    if not err_handler.HadError(true) then
    try
      d(o,c);
    except
      on e: Exception do err_handler.AddErr(e);
    end;
    static function HandlerWrap<T,TRes>(err_handler: CLTaskErrHandler; d: (T,Context)->TRes): (T,Context)->TRes := (o,c)->
    if not err_handler.HadError(true) then
    try
      Result := d(o,c);
    except
      on e: Exception do err_handler.AddErr(e);
    end;
    static function HandlerWrapStrip<T,TRes>(err_handler: CLTaskErrHandler; d: (T,Context)->TRes): (T,Context)->() := (o,c)->
    if not err_handler.HadError(true) then
    try
      d(o,c);
    except
      on e: Exception do err_handler.AddErr(e);
    end;
    
  end;
  
  [StructLayout(LayoutKind.Auto)]
  QueueResComplDelegateData = record
    private call_list: array of QueueResAction := nil;
    private count := 0;
    
    private const initial_cap = 4;
    
    public constructor := exit;
    public constructor(d: QueueResAction);
    begin
      call_list := new QueueResAction[initial_cap];
      call_list[0] := d;
      count := 1;
    end;
    
    public procedure AddAction(d: QueueResAction);
    begin
      if call_list=nil then
        call_list := new QueueResAction[initial_cap] else
      if count=call_list.Length then
        System.Array.Resize(call_list, call_list.Length * 4);
      call_list[count] := d;
      count += 1;
    end;
    
    {$ifdef DEBUG}
    private was_invoked := false;
    {$endif DEBUG}
    public procedure Invoke(c: Context);
    begin
      {$ifdef DEBUG}
      if was_invoked then raise new System.InvalidProgramException($'{self.GetType}: {System.Environment.StackTrace}');
      was_invoked := true;
      {$endif DEBUG}
      for var i := 0 to count-1 do
        call_list[i](c);
    end;
    
  end;
  
{$endregion QueueResAction}

{$region CLTaskLocalData}

type
  [StructLayout(LayoutKind.Auto)]
  CLTaskLocalData = record
    public prev_delegate := default(QueueResComplDelegateData);
    public prev_ev := EventList.Empty;
    
    public constructor := exit;
    public constructor(ev: EventList) := self.prev_ev := ev;
    
    public function ShouldInstaCallAction: boolean;
    begin
      // Only const can have not events
      Result := prev_ev.count=0;
      {$ifdef DEBUG}
      if prev_delegate.count<>0 then raise new OpenCLABCInternalException($'Broken Quick.Invoke detected');
      {$endif DEBUG}
    end;
    
  end;
  
{$endregion CLTaskLocalData}

{$region QueueRes}

type
  {$region Base}
  
  IQueueRes = interface
    
    property ResEv: EventList read;
    
    procedure AddAction(d: QueueResAction);
    property HasActions: boolean read;
    procedure InvokeActions(c: Context);
    function ShouldInstaCallAction: boolean;
    
  end;
  
  IQueueResBaseFactory<TR> = interface
    where TR: IQueueRes;
    
    function MakeDelayed(l: CLTaskLocalData): TR;
    function MakeDelayed(make_l: TR->CLTaskLocalData): TR;
    
  end;
  
  [StructLayout(LayoutKind.Auto)]
  QueueResData = record
    private complition_delegate  := default(QueueResComplDelegateData);
    private ev                   := EventList.Empty;
    
    public static function operator implicit(base: QueueResData): CLTaskLocalData;
    begin
      Result := new CLTaskLocalData(base.ev);
      Result.prev_delegate := base.complition_delegate;
    end;
    
    public property ResEv: EventList read ev;
    
    public procedure AddAction(d: QueueResAction) :=
    complition_delegate.AddAction(d);
    
    public procedure InvokeActions(c: Context) := complition_delegate.Invoke(c);
    
    public function ShouldInstaCallAction := CLTaskLocalData(self).ShouldInstaCallAction;
    
    protected procedure Finalize; override;
    begin
      {$ifdef DEBUG}
      if not complition_delegate.was_invoked then raise new System.InvalidProgramException($'{self.GetType}');
      {$endif DEBUG}
    end;
    
  end;
  
  {$endregion Base}
  
  {$region Nil}
  
  [StructLayout(LayoutKind.Auto)]
  QueueResNil = record(IQueueRes)
    private base: QueueResData;
    
    public constructor(l: CLTaskLocalData);
    begin
      base.ev := l.prev_ev;
      base.complition_delegate := l.prev_delegate;
    end;
    public constructor := raise new OpenCLABCInternalException;
    
    public property ResEv: EventList read base.ResEv;
    
    public procedure AddAction(d: QueueResAction) := base.AddAction(d);
    public property HasActions: boolean read base.complition_delegate.count<>0;
    public procedure InvokeActions(c: Context) := base.InvokeActions(c);
    public function ShouldInstaCallAction := base.ShouldInstaCallAction;
    
  end;
  QueueResNilFactory = record(IQueueResBaseFactory<QueueResNil>)
    
    function MakeDelayed(l: CLTaskLocalData) := new QueueResNil(l);
    function MakeDelayed(make_l: QueueResNil->CLTaskLocalData) := new QueueResNil(make_l(default(QueueResNil)));
    
  end;
  
  {$endregion Nil}
  
  {$region <T>}
  
  {$region General}
  
  QueueResT = abstract partial class(IQueueRes)
    private base: QueueResData;
    private res_const: boolean; // Whether res can be read before event completes
    {$ifdef DEBUG}
    private res_setter_exists := false;
    {$endif DEBUG}
    
    public property ResEv: EventList read; abstract;
    
    public procedure AddAction(d: QueueResAction) := base.AddAction(d);
    public property HasActions: boolean read base.complition_delegate.count<>0;
    public procedure InvokeActions(c: Context) := base.InvokeActions(c);
    public function ShouldInstaCallAction := base.ShouldInstaCallAction;
    
    public procedure TransplantActionsTo(qr: QueueResT);
    begin
      qr.base.complition_delegate := self.base.complition_delegate;
      self.base.complition_delegate := default(QueueResComplDelegateData);
      {$ifdef DEBUG}
      self.base.complition_delegate.was_invoked := true;
      {$endif DEBUG}
    end;
    // Delete actions from self. For when QueueResNil was created from base
    public procedure TransplantActionsNowhere := TransplantActionsTo(self);
    
  end;
  
  QueueRes<T> = abstract partial class(QueueResT) end;
  IQueueResFactory<T,TR> = interface(IQueueResBaseFactory<TR>)
    where TR: QueueRes<T>;
    
    function MakeConst(l: CLTaskLocalData; res: T): TR;
    
  end;
  
  QueueRes<T> = abstract partial class(QueueResT)
    
    protected procedure InitDelayed(l: CLTaskLocalData);
    begin
      {$ifdef DEBUG}
      if l.prev_ev.count=0 then raise new OpenCLABCInternalException($'Delayed QueueRes, but it is not delayed');
      {$endif DEBUG}
      base.ev := l.prev_ev;
      base.complition_delegate := l.prev_delegate;
    end;
    
    protected procedure InitConst(l: CLTaskLocalData; res: T);
    begin
      base.ev := l.prev_ev;
      base.complition_delegate := l.prev_delegate;
      SetResDirect(res);
      res_const := true;
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function WrapResult<TR>(factory: IQueueResFactory<T,TR>; new_ev: EventList): TR; where TR: QueueRes<T>;
    begin
      {$ifdef DEBUG}
      if self.HasActions then raise new OpenCLABCInternalException($'Broken MU.Invoke detected');
      {$endif DEBUG}
      var l := new CLTaskLocalData(new_ev);
      if res_const then
        Result := factory.MakeConst(l, self.GetResDirect) else
      begin
        Result := factory.MakeDelayed(l);
        Result.AddResSetter(c->self.GetResDirect);
      end;
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function TransformResult<T2,TR>(factory: IQueueResFactory<T2,TR>; c: Context; can_insta_call: boolean; transform: (T,Context)->T2): TR; where TR: QueueRes<T2>;
    begin
      // actions are transplanted at the end
      var res_l := new CLTaskLocalData(self.ResEv);
      
      if self.ShouldInstaCallAction or (res_const and can_insta_call) then
        Result := factory.MakeConst(res_l, transform(self.GetResDirect, c)) else
      begin
        Result := factory.MakeDelayed(res_l);
        Result.AddResSetter(c->transform(self.GetResDirect, c));
      end;
      
      self.TransplantActionsTo(Result);
    end;
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function TransformResultErrWrap<T2,TR>(factory: IQueueResFactory<T2,TR>; g: CLTaskGlobalData; can_insta_call: boolean; transform: (T,Context)->T2): TR; where TR: QueueRes<T2>;
    begin
      //TODO #2644: &<>
      transform := QueueResActionUtils.HandlerWrap&<T,T2>(g.curr_err_handler, transform);
      Result := TransformResult(factory, g.c, can_insta_call, transform);
    end;
    
    public property ResEv: EventList read base.ResEv; override;
    
    public property IsConst: boolean read res_const;
    
    public procedure AddResSetter(d: Context->T);
    begin
      {$ifdef DEBUG}
      if res_const then raise new OpenCLABCInternalException($'Result setter action on const qr');
      if res_setter_exists then raise new OpenCLABCInternalException($'Multiple result setter actions');
      res_setter_exists := true;
      {$endif DEBUG}
      AddAction(c->self.SetRes(d(c)));
    end;
    public procedure SetRes(res: T);
    begin
      {$ifdef DEBUG}
      if res_const then raise new OpenCLABCInternalException($'');
      {$endif DEBUG}
      SetResDirect(res);
    end;
    protected procedure SetResDirect(res: T); abstract;
    public function GetRes(c: Context): T;
    begin
      InvokeActions(c);
      Result := GetResDirect;
    end;
    protected function GetResDirect: T; abstract;
    
  end;
  
  {$endregion General}
  
  {$region Val}
  
  QueueResVal<T> = sealed class(QueueRes<T>)
    private res: T;
    
    public constructor(l: CLTaskLocalData) := InitDelayed(l);
    public constructor(make_l: QueueResVal<T>->CLTaskLocalData) := InitDelayed(make_l(self));
    
    public constructor(l: CLTaskLocalData; res: T) := InitConst(l, res);
    public constructor(make_l: QueueResVal<T>->CLTaskLocalData; res: T) := InitConst(make_l(self), res);
    
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure SetResDirect(res: T); override := self.res := res;
    protected function GetResDirect: T; override := self.res;
    
  end;
  QueueResValFactory<T> = record(IQueueResFactory<T, QueueResVal<T>>)
    
    public function MakeConst(l: CLTaskLocalData; res: T) := new QueueResVal<T>(l, res);
    
    public function MakeDelayed(l: CLTaskLocalData) := new QueueResVal<T>(l);
    public function MakeDelayed(make_l: QueueResVal<T>->CLTaskLocalData) := new QueueResVal<T>(make_l);
    
  end;
  QueueRes<T> = abstract partial class(QueueResT)
    public static val_factory := new QueueResValFactory<T>;
  end;
  
  {$endregion Val}
  
  {$region Ptr}
  
  QueueResPtr<T> = sealed class(QueueRes<T>)
    private res: ^T := pointer(Marshal.AllocHGlobal(Marshal.SizeOf&<T>));
    
    static constructor := BlittableHelper.RaiseIfBad(typeof(T), '%Err:Blittable:Source:QueueResPtr%');
    
    public constructor(l: CLTaskLocalData) := InitDelayed(l);
    public constructor(make_l: QueueResPtr<T>->CLTaskLocalData) := InitDelayed(make_l(self));
    
    public constructor(l: CLTaskLocalData; res: T) := InitConst(l, res);
    public constructor(make_l: QueueResPtr<T>->CLTaskLocalData; res: T) := InitConst(make_l(self), res);
    
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure Finalize; override;
    begin
      Marshal.FreeHGlobal(new IntPtr(res));
      inherited;
    end;
    
    protected procedure SetResDirect(res: T); override := self.res^ := res;
    protected function GetResDirect: T; override := self.res^;
    
  end;
  QueueResPtrFactory<T> = record(IQueueResFactory<T, QueueResPtr<T>>)
    
    public function MakeConst(l: CLTaskLocalData; res: T) := new QueueResPtr<T>(l, res);
    
    public function MakeDelayed(l: CLTaskLocalData) := new QueueResPtr<T>(l);
    public function MakeDelayed(make_l: QueueResPtr<T>->CLTaskLocalData) := new QueueResPtr<T>(make_l);
    
  end;
  QueueRes<T> = abstract partial class(QueueResT)
    public static ptr_factory := new QueueResPtrFactory<T>;
  end;
  
  {$endregion Ptr}
  
  {$endregion <T>}
  
//TODO #????
procedure TODO := exit;

[MethodImpl(MethodImplOptions.AggressiveInlining)]
function AttachInvokeActions(self: IQueueRes; g: CLTaskGlobalData): EventList; extensionmethod;
begin
  if not self.HasActions then
  begin
    Result := self.ResEv;
    exit;
  end else
  {$ifdef DEBUG}
  if self.ShouldInstaCallAction then // auto raise
  {$endif DEBUG}
    ;
  
  var uev := new UserEvent(g.cl_c{$ifdef EventDebug}, $'res_ev for {self.GetType}.ThenAttachInvokeActions, after [{self.ResEv.evs?.JoinToString}]'{$endif});
  Result := uev;
  
  var c := g.c;
  self.ResEv.MultiAttachCallback(()->
  begin
    self.InvokeActions(c);
    uev.SetComplete;
  end{$ifdef EventDebug}, $'body of {self.GetType}.ThenAttachInvokeActions with res_ev={uev}'{$endif});
  
end;
//TODO #????
function AttachInvokeActions<T>(self: QueueRes<T>; g: CLTaskGlobalData); extensionmethod := (self as IQueueRes).AttachInvokeActions(g);

{$endregion QueueRes}

{$region MultiusableBase}

type
  IMultiusableCommandQueueHub = interface end;
  [StructLayout(LayoutKind.Auto)]
  MultiuseableResultData = record
    public qres: IQueueRes;
    public ev: EventList;
    public err_handler: CLTaskErrHandler;
    
    public constructor(qres: IQueueRes; ev: EventList; err_handler: CLTaskErrHandler);
    begin
      self.qres := qres;
      self.ev := ev;
      self.err_handler := err_handler;
    end;
    
  end;
  
{$endregion MultiusableBase}

{$region CLTaskGlobalData/BkanchInvoker}

type
  CLTaskBranchInvoker = sealed class
    private prev_cq: cl_command_queue;
    private g: CLTaskGlobalData;
    private prev_ev: EventList;
    private branch_handlers := new List<CLTaskErrHandler>;
    private make_base_err_handler: ()->CLTaskErrHandler;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    constructor(g: CLTaskGlobalData; prev_ev: EventList; as_new: boolean; capacity: integer);
    begin
      self.prev_cq := if as_new then g.curr_inv_cq else cl_command_queue.Zero;
      self.g := g;
      self.prev_ev := prev_ev;
      self.branch_handlers.Capacity := capacity;
      if as_new then
        self.make_base_err_handler := ()->new CLTaskErrHandlerEmpty else
      begin
        var origin_handler := g.curr_err_handler;
        self.make_base_err_handler := ()->new CLTaskErrHandlerBranchBase(origin_handler);
      end;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function InvokeBranch<TR>(branch: (CLTaskGlobalData, CLTaskLocalData)->TR): TR; where TR: IQueueRes;
    begin
      g.curr_err_handler := make_base_err_handler();
      
      Result := branch(g, new CLTaskLocalData(self.prev_ev));
      
      var cq := g.curr_inv_cq;
      if cq<>cl_command_queue.Zero then
      begin
        g.curr_inv_cq := cl_command_queue.Zero;
        if prev_cq=cl_command_queue.Zero then
          prev_cq := cq else
          Result.AddAction(c->self.g.ReturnCQ(cq));
      end;
      
      branch_handlers += g.curr_err_handler;
    end;
    
  end;
  
  CLTaskGlobalData = sealed partial class
    
    public mu_res := new Dictionary<IMultiusableCommandQueueHub, MultiuseableResultData>;
    
    public constructor(tsk: CLTaskBase);
    begin
      self.tsk := tsk;
      
      self.c := tsk.OrgContext;
      self.cl_c := c.ntv;
      self.cl_dvc := c.main_dvc.ntv;
      
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure ParallelInvoke(l: CLTaskLocalData; as_new: boolean; capacity: integer; use: Action<CLTaskBranchInvoker>);
    begin
      var prev_ev := QueueResNil.Create(l).AttachInvokeActions(self);
      if prev_ev.count<>0 then loop capacity-1 do
        prev_ev.Retain({$ifdef EventDebug}$'for all async branches'{$endif});
      
      var invoker := new CLTaskBranchInvoker(self, prev_ev, as_new, capacity);
      var origin_handler := self.curr_err_handler;
      
      // Только в случае A + B*C, то есть "not as_new", можно использовать curr_inv_cq - и только как outer_cq
      if not as_new and (curr_inv_cq<>cl_command_queue.Zero) then
      begin
        {$ifdef DEBUG}
        if outer_cq<>cl_command_queue.Zero then raise new OpenCLABCInternalException($'OuterCQ confusion');
        {$endif DEBUG}
        outer_cq := curr_inv_cq;
      end;
      curr_inv_cq := cl_command_queue.Zero;
      
      use(invoker);
      
      {$ifdef DEBUG}
      if invoker.branch_handlers.Count<>capacity then
        raise new OpenCLABCInternalException($'{invoker.branch_handlers.Count} <> {capacity}');
      {$endif DEBUG}
      self.curr_err_handler := new CLTaskErrHandlerBranchCombinator(origin_handler, invoker.branch_handlers.ToArray);
      
      self.curr_inv_cq := invoker.prev_cq;
      if outer_cq<>cl_command_queue.Zero then self.GetCQ(false);
    end;
    
    public procedure FinishInvoke;
    begin
      
      // mu выполняют лишний .Retain, чтобы ивент не удалился пока очередь ещё запускается
      foreach var mrd in mu_res.Values do
        mrd.ev.Release({$ifdef EventDebug}$'excessive mu ev'{$endif});
      mu_res := nil;
      
    end;
    
    public procedure FinishExecution(var err_lst: List<Exception>);
    begin
      
      if curr_inv_cq<>cl_command_queue.Zero then
        ReturnCQ(curr_inv_cq);
      
      foreach var cq in free_cqs do
        OpenCLABCInternalException.RaiseIfError( cl.ReleaseCommandQueue(cq) );
      
      err_lst := new List<Exception>;
      curr_err_handler.FillErrLst(err_lst);
      {$ifdef DEBUG}
      curr_err_handler.SanityCheck(err_lst);
      {$endif DEBUG}
    end;
    
  end;
  
{$endregion CLTaskData}

{$endregion Util type's}

{$region CommandQueue}

{$region Base}

type
  CommandQueueBase = abstract partial class
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); abstract;
    
    protected static qr_nil_factory := new QueueResNilFactory;
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; abstract;
    
  end;
  
  CommandQueueNil = abstract partial class(CommandQueueBase)
    
  end;
  
  CommandQueue<T> = abstract partial class(CommandQueueBase)
    
    protected static qr_val_factory := QueueRes&<T>.val_factory;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; abstract;
    
    protected static qr_ptr_factory := QueueRes&<T>.ptr_factory;
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; abstract;
    
    protected function InvokeToAny(g: CLTaskGlobalData; l: CLTaskLocalData): QueueRes<T>; virtual := InvokeToVal(g, l);
    
  end;
  
  CommandQueueInvoker<TR> = (CLTaskGlobalData,CLTaskLocalData)->TR;
  
{$endregion Base}

{$region Const}

type
  ConstQueue<T> = sealed partial class(CommandQueue<T>)
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;    override := new QueueResNil(l);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := new QueueResVal<T>(l, self.res);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := new QueueResPtr<T>(l, self.res);
    
  end;
  
{$endregion Const}

{$region Parameter}

type
  ParameterQueue<T> = sealed partial class(CommandQueue<T>, IParameterQueue)
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override;
    begin
      //TODO #????
      if g.parameters.ContainsKey(self as object as IParameterQueue) then exit;
      //TODO #????
      g.parameters[self as object as IParameterQueue] := if self.def_is_set then
        new CLTaskParameterData(self.def) else
        new CLTaskParameterData;
    end;
    
    private function GetParVal(g: CLTaskGlobalData) :=
    //TODO #????
    T(g.parameters[self as object as IParameterQueue].val);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;    override := new QueueResNil(l);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := new QueueResVal<T>(l, self.GetParVal(g));
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := new QueueResPtr<T>(l, self.GetParVal(g));
    
  end;
  
{$endregion Parameter}

{$endregion CommandQueue}

{$region CLTask}

type
  CLTaskBase = abstract partial class
    
  end;
  
  CLTaskNil = sealed partial class(CLTaskBase)
    
    private constructor(q: CommandQueueNil; c: Context; pars: array of ParameterQueueSetter);
    begin
      self.q := q;
      self.org_c := c;
      
      var g := new CLTaskGlobalData(self);
      
      q.InitBeforeInvoke(g, new HashSet<IMultiusableCommandQueueHub>);
      g.ApplyParameters(pars);
      var qr := q.InvokeToNil(g, new CLTaskLocalData);
      g.FinishInvoke;
      
      var mre := qr.ResEv.ToMRE({$ifdef EventDebug}$'CLTaskNil.FinishExecution'{$endif});
      NativeUtils.StartNewBgThread(()->
      begin
        if mre<>nil then mre.WaitOne;
        qr.InvokeActions(self.org_c);
        g.FinishExecution(self.err_lst);
        self.wh.Set;
      end);
      
    end;
    
  end;
  CLTask<T> = sealed partial class(CLTaskBase)
    private res: T;
    
    private constructor(q: CommandQueue<T>; c: Context; pars: array of ParameterQueueSetter);
    begin
      self.q := q;
      self.org_c := c;
      
      var g := new CLTaskGlobalData(self);
      
      q.InitBeforeInvoke(g, new HashSet<IMultiusableCommandQueueHub>);
      g.ApplyParameters(pars);
      var qr := q.InvokeToAny(g, new CLTaskLocalData);
      g.FinishInvoke;
      
      var mre := qr.ResEv.ToMRE({$ifdef EventDebug}$'CLTask<{typeof(T)}>.FinishExecution'{$endif});
      NativeUtils.StartNewBgThread(()->
      begin
        if mre<>nil then mre.WaitOne;
        self.res := qr.GetRes(self.org_c);
        g.FinishExecution(self.err_lst);
        self.wh.Set;
      end);
      
    end;
    
  end;
  
  CLTaskFactory = record(ITypedCQConverter<CLTaskBase>)
    private c: Context;
    private pars: array of ParameterQueueSetter;
    public constructor(c: Context; pars: array of ParameterQueueSetter);
    begin
      self.c := c;
      self.pars := pars;
    end;
    public constructor := raise new OpenCLABCInternalException;
    
    public function ConvertNil(cq: CommandQueueNil): CLTaskBase := new CLTaskNil(cq, c, pars);
    public function Convert<T>(cq: CommandQueue<T>): CLTaskBase := new CLTask<T>(cq, c, pars);
    
  end;
  
function Context.BeginInvoke(q: CommandQueueBase; params parameters: array of ParameterQueueSetter) := q.ConvertTyped(new CLTaskFactory(self, parameters));
function Context.BeginInvoke(q: CommandQueueNil; params parameters: array of ParameterQueueSetter) := new CLTaskNil(q, self, parameters);
function Context.BeginInvoke<T>(q: CommandQueue<T>; params parameters: array of ParameterQueueSetter) := new CLTask<T>(q, self, parameters);

function CLTask<T>.WaitRes: T;
begin
  Wait;
  Result := self.res;
end;

{$endregion CLTask}

{$region Queue converter's}

{$region Cast}

type
  TypedNilQueue<T> = sealed class(CommandQueue<T>)
    private static nil_val := default(T);
    private q: CommandQueueNil;
    
    static constructor;
    begin
      if object(nil_val)<>nil then
        raise new System.InvalidCastException($'%Err:Cast:nil->T%');
    end;
    public constructor(q: CommandQueueNil) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := q.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := q.InvokeToNil(g, l);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := new QueueResVal<T>(q.InvokeToNil(g, l).base, nil_val);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := new QueueResPtr<T>(q.InvokeToNil(g, l).base, nil_val);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  CastQueueBase<TRes> = abstract class(CommandQueue<TRes>)
    
    public property SourceBase: CommandQueueBase read; abstract;
    
  end;
  
  CastQueue<TInp, TRes> = sealed class(CastQueueBase<TRes>)
    private q: CommandQueue<TInp>;
    
    static constructor;
    begin
      if typeof(TInp)=typeof(object) then exit;
      try
        var res := TRes(object(default(TInp)));
        System.GC.KeepAlive(res);
      except
        raise new System.InvalidCastException($'%Err:Cast:TInp->TRes%');
      end;
    end;
    public constructor(q: CommandQueue<TInp>) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    public property SourceBase: CommandQueueBase read q as CommandQueueBase; override;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := q.InvokeToNil(g, l);
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<TRes,TR>): TR; where TR: QueueRes<TRes>;
    begin
      var prev_qr := q.InvokeToAny(g,l);
      Result := prev_qr.TransformResultErrWrap(qr_factory, g, true, (o,c)->TRes(object(o)));
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := Invoke(g, l, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  CastQueueFactory<TRes> = record(ITypedCQConverter<CommandQueue<TRes>>)
    
    public function ConvertNil(cq: CommandQueueNil): CommandQueue<TRes> := new TypedNilQueue<TRes>(cq);
    public function Convert<TInp>(cq: CommandQueue<TInp>): CommandQueue<TRes>;
    begin
      if cq is CastQueueBase<TInp>(var cqb) then
        Result := cqb.SourceBase.Cast&<TRes> else
        Result := new CastQueue<TInp, TRes>(cq);
    end;
    
  end;
  
function CommandQueueBase.Cast<T>: CommandQueue<T>;
begin
  if self is CommandQueue<T>(var tcq) then
    Result := tcq else
  try
    Result := self.ConvertTyped(new CastQueueFactory<T>);
  except
    on e: TypeInitializationException do
      raise e.InnerException;
    on e: InvalidCastException do
      raise e;
  end;
end;

function CommandQueueNil.Cast<T> := new TypedNilQueue<T>(self);

{$endregion Cast}

{$region DiscardResult}

type
  CommandQueueDiscardResult<T> = sealed class(CommandQueueNil)
    private q: CommandQueue<T>;
    
    public constructor(q: CommandQueue<T>) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := q.InvokeToNil(g, l);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
function CommandQueue<T>.DiscardResult :=
new CommandQueueDiscardResult<T>(self);

{$endregion DiscardResult}

{$region BackgroundConvertQueue}

type
  BackgroundConvertQueue<TInp,TRes> = abstract class(CommandQueue<TRes>)
    
    protected function InvokeSubQs(g: CLTaskGlobalData; l: CLTaskLocalData): QueueRes<TInp>; abstract;
    
    protected function ExecFunc(o: TInp; c: Context): TRes; abstract;
    
    private function MakeNilBody    (prev_qr: QueueRes<TInp>; err_handler: CLTaskErrHandler; c: Context; own_qr: QueueResNil): Action := ()->
    begin
      var inp := prev_qr.GetRes(c);
      if err_handler.HadError(true) then exit;
      try
        ExecFunc(inp, c);
      except
        on e: Exception do err_handler.AddErr(e);
      end;
    end;
    private function MakeResBody<TR>(prev_qr: QueueRes<TInp>; err_handler: CLTaskErrHandler; c: Context; own_qr: TR): Action; where TR: QueueRes<TRes>;
    begin
      Result := ()->
      begin
        var inp := prev_qr.GetRes(c);
        if err_handler.HadError(true) then exit;
        var res: TRes;
        try
          res := ExecFunc(inp, c);
        except
          on e: Exception do err_handler.AddErr(e);
        end;
        own_qr.SetRes(res);
      end;
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResBaseFactory<TR>; make_body: (QueueRes<TInp>,CLTaskErrHandler,Context,TR)->Action): TR; where TR: IQueueRes;
    begin
      var prev_qr := InvokeSubQs(g, l);
      
      Result := qr_factory.MakeDelayed(qr->new CLTaskLocalData(UserEvent.StartBackgroundWork(
        prev_qr.ResEv, make_body(prev_qr, g.curr_err_handler, g.c, qr), g.cl_c
        {$ifdef EventDebug}, $'body of {self.GetType}'{$endif}
      )));
      
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;       override := Invoke(g, l, qr_nil_factory, MakeNilBody);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override := Invoke(g, l, qr_val_factory, MakeResBody&<QueueResVal<TRes>>);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := Invoke(g, l, qr_ptr_factory, MakeResBody&<QueueResPtr<TRes>>);
    
  end;
  
{$endregion BackgroundConvertQueue}

{$region ThenBackgroundConvert}

type
  CommandQueueThenBackgroundConvertBase<TInp, TRes, TFunc> = abstract class(BackgroundConvertQueue<TInp, TRes>)
  where TFunc: Delegate;
    private q: CommandQueue<TInp>;
    private f: TFunc;
    
    public constructor(q: CommandQueue<TInp>; f: TFunc);
    begin
      self.q := q;
      self.f := f;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeSubQs(g: CLTaskGlobalData; l: CLTaskLocalData): QueueRes<TInp>; override := q.InvokeToAny(g, l);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, f);
      sb += #10;
      
    end;
    
  end;
  
  CommandQueueThenBackgroundConvert<TInp, TRes> = sealed class(CommandQueueThenBackgroundConvertBase<TInp, TRes, TInp->TRes>)
    
    protected function ExecFunc(o: TInp; c: Context): TRes; override := f(o);
    
  end;
  CommandQueueThenBackgroundConvertC<TInp, TRes> = sealed class(CommandQueueThenBackgroundConvertBase<TInp, TRes, (TInp, Context)->TRes>)
    
    protected function ExecFunc(o: TInp; c: Context): TRes; override := f(o, c);
    
  end;
  
function CommandQueue<T>.ThenConvert<TOtp>(f: T->TOtp) :=
new CommandQueueThenBackgroundConvert<T, TOtp>(self, f);

function CommandQueue<T>.ThenConvert<TOtp>(f: (T, Context)->TOtp) :=
new CommandQueueThenBackgroundConvertC<T, TOtp>(self, f);

{$endregion ThenBackgroundConvert}

{$region ThenBackgroundUse}

type
  CommandQueueThenBackgroundUseBase<T, TProc> = abstract class(CommandQueue<T>)
  where TProc: Delegate;
    private q: CommandQueue<T>;
    private p: TProc;
    
    public constructor(q: CommandQueue<T>; p: TProc);
    begin
      self.q := q;
      self.p := p;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    protected procedure ExecProc(o: T; c: Context); abstract;
    
    private function MakeNilBody    (prev_qr: QueueRes<T>; err_handler: CLTaskErrHandler; c: Context): Action := ()->
    begin
      var res := prev_qr.GetRes(c);
      if err_handler.HadError(true) then exit;
      try
        ExecProc(res, c);
      except
        on e: Exception do err_handler.AddErr(e);
      end;
    end;
    private function MakeResBody<TR>(prev_qr: QueueRes<T>; err_handler: CLTaskErrHandler; c: Context; own_qr: TR): Action; where TR: QueueRes<T>;
    begin
      Result := ()->
      begin
        var res := prev_qr.GetRes(c);
        if err_handler.HadError(true) then exit;
        try
          ExecProc(res, c);
        except
          on e: Exception do err_handler.AddErr(e);
        end;
        own_qr.SetRes(res);
      end;
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var prev_qr := q.InvokeToAny(g, l);
      
      Result := new QueueResNil(new CLTaskLocalData(UserEvent.StartBackgroundWork(
        prev_qr.ResEv, MakeNilBody(prev_qr, g.curr_err_handler, g.c), g.cl_c
        {$ifdef EventDebug}, $'nil body of {self.GetType}'{$endif}
      )));
      
    end;
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      var prev_qr := q.InvokeToAny(g, l);
      
      Result := if prev_qr.IsConst then
        qr_factory.MakeConst(
          new CLTaskLocalData(UserEvent.StartBackgroundWork(
            prev_qr.ResEv, MakeNilBody(prev_qr, g.curr_err_handler, g.c), g.cl_c
            {$ifdef EventDebug}, $'const body of {self.GetType}'{$endif}
          )), prev_qr.GetResDirect
        ) else
        qr_factory.MakeDelayed(
          qr->new CLTaskLocalData(UserEvent.StartBackgroundWork(
            prev_qr.ResEv, MakeResBody(prev_qr, g.curr_err_handler, g.c, qr), g.cl_c
            {$ifdef EventDebug}, $'delayed body of {self.GetType}'{$endif}
          ))
        );
      
    end;
    
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(g, l, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, p);
      sb += #10;
      
    end;
    
  end;
  
  CommandQueueThenBackgroundUse<T> = sealed class(CommandQueueThenBackgroundUseBase<T, T->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o);
    
  end;
  CommandQueueThenBackgroundUseC<T> = sealed class(CommandQueueThenBackgroundUseBase<T, (T, Context)->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o, c);
    
  end;
  
function CommandQueue<T>.ThenUse(p: T->()): CommandQueue<T> :=
new CommandQueueThenBackgroundUse<T>(self, p);

function CommandQueue<T>.ThenUse(p: (T, Context)->()): CommandQueue<T> :=
new CommandQueueThenBackgroundUseC<T>(self, p);

{$endregion ThenBackgroundUse}

{$region ThenQuickConvert}

type
  CommandQueueThenQuickConvertBase<TInp, TRes, TFunc> = abstract class(CommandQueue<TRes>)
  where TFunc: Delegate;
    private q: CommandQueue<TInp>;
    private f: TFunc;
    
    public constructor(q: CommandQueue<TInp>; f: TFunc);
    begin
      self.q := q;
      self.f := f;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := q.InitBeforeInvoke(g, inited_hubs);
    
    protected function ExecFunc(o: TInp; c: Context): TRes; abstract;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var prev_qr := q.InvokeToAny(g, l);
      Result := new QueueResNil(prev_qr.base);
      
      var d := QueueResActionUtils.HandlerWrapStrip(g.curr_err_handler, ExecFunc);
      if prev_qr.ShouldInstaCallAction then
        d(prev_qr.GetResDirect, g.c) else
        Result.AddAction(c->d(prev_qr.GetResDirect,c));
      
      prev_qr.TransplantActionsNowhere;
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<TRes,TR>): TR; where TR: QueueRes<TRes>;
    begin
      var prev_qr := q.InvokeToAny(g, l);
      Result := prev_qr.TransformResultErrWrap(qr_factory, g, false, ExecFunc);
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := Invoke(g, l, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, f);
      sb += #10;
      
    end;
    
  end;
  
  CommandQueueThenQuickConvert<TInp, TRes> = sealed class(CommandQueueThenQuickConvertBase<TInp, TRes, TInp->TRes>)
    
    protected function ExecFunc(o: TInp; c: Context): TRes; override := f(o);
    
  end;
  CommandQueueThenQuickConvertC<TInp, TRes> = sealed class(CommandQueueThenQuickConvertBase<TInp, TRes, (TInp, Context)->TRes>)
    
    protected function ExecFunc(o: TInp; c: Context): TRes; override := f(o, c);
    
  end;
  
function CommandQueue<T>.ThenQuickConvert<TOtp>(f: T->TOtp) :=
new CommandQueueThenQuickConvert<T, TOtp>(self, f);

function CommandQueue<T>.ThenQuickConvert<TOtp>(f: (T, Context)->TOtp) :=
new CommandQueueThenQuickConvertC<T, TOtp>(self, f);

{$endregion ThenQuickConvert}

{$region ThenQuickUse}

type
  CommandQueueThenQuickUseBase<T, TProc> = abstract class(CommandQueue<T>)
  where TProc: Delegate;
    private q: CommandQueue<T>;
    private p: TProc;
    
    public constructor(q: CommandQueue<T>; p: TProc);
    begin
      self.q := q;
      self.p := p;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := q.InitBeforeInvoke(g, inited_hubs);
    
    protected procedure ExecProc(o: T; c: Context); abstract;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function AddUse<TR1, TR2>(prev_qr: TR1; own_qr: TR2; g: CLTaskGlobalData): TR2; where TR1: QueueRes<T>; where TR2: IQueueRes;
    begin
      Result := own_qr;
      
      var d := QueueResActionUtils.HandlerWrap(g.curr_err_handler, ExecProc);
      if prev_qr.ShouldInstaCallAction then
        d(prev_qr.GetResDirect, g.c) else
        Result.AddAction(c->d(prev_qr.GetResDirect, c));
      
    end;
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function AddUse<TR>(qr: TR; g: CLTaskGlobalData): TR; where TR: QueueRes<T>;
    begin
      Result := AddUse(qr,qr, g);
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var prev_qr := q.InvokeToAny(g, l);
      Result := AddUse(prev_qr, new QueueResNil(prev_qr.base), g);
      prev_qr.TransplantActionsNowhere;
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := AddUse(q.InvokeToVal(g, l), g);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := AddUse(q.InvokeToPtr(g, l), g);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, p);
      sb += #10;
      
    end;
    
  end;
  
  CommandQueueThenQuickUse<T> = sealed class(CommandQueueThenQuickUseBase<T, T->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o);
    
  end;
  CommandQueueThenQuickUseC<T> = sealed class(CommandQueueThenQuickUseBase<T, (T, Context)->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o, c);
    
  end;
  
function CommandQueue<T>.ThenQuickUse(p: T->()) :=
new CommandQueueThenQuickUse<T>(self, p);

function CommandQueue<T>.ThenQuickUse(p: (T, Context)->()) :=
new CommandQueueThenQuickUseC<T>(self, p);

{$endregion ThenQuickUse}

{$region +/*}

{$region Simple}

type
  SimpleQueueArrayCommon<TQ> = record
  where TQ: CommandQueueBase;
    public qs: array of CommandQueueBase;
    public last: TQ;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function GetQS: sequence of CommandQueueBase := qs.Append&<CommandQueueBase>(last);
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>);
    begin
      foreach var q in qs do q.InitBeforeInvoke(g, inited_hubs);
      last.InitBeforeInvoke(g, inited_hubs);
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function InvokeSync<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; invoke_last: CommandQueueInvoker<TR>): TR; where TR: IQueueRes;
    begin
      for var i := 0 to qs.Length-1 do
        l := qs[i].InvokeToNil(g, l).base;
      
      Result := invoke_last(g, l);
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function InvokeAsync<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; invoke_last: CommandQueueInvoker<TR>): ValueTuple<TR, EventList>; where TR: IQueueRes;
    begin
      var evs := new EventList[qs.Length+1];
      
      var res: TR;
      g.ParallelInvoke(l, false, qs.Length+1, invoker->
      begin
        for var i := 0 to qs.Length-1 do
          //TODO #2610
          evs[i] := invoker.InvokeBranch&<IQueueRes>((g,l)->
            qs[i].InvokeToNil(g, l)
          ).AttachInvokeActions(g);
        var l_res := invoker.InvokeBranch(invoke_last);
        res := l_res;
        evs[qs.Length] := l_res.AttachInvokeActions(g);
      end);
      
      Result := ValueTuple.Create(res, EventList.Combine(evs));
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>);
    begin
      sb += #10;
      foreach var q in qs do
        q.ToString(sb, tabs, index, delayed);
      last.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  ISimpleQueueArray = interface
    function GetQS: sequence of CommandQueueBase;
  end;
  ISimpleSyncQueueArray = interface(ISimpleQueueArray) end;
  ISimpleAsyncQueueArray = interface(ISimpleQueueArray) end;
  
  SimpleQueueArrayNil = abstract class(CommandQueueNil, ISimpleQueueArray)
    protected data := new SimpleQueueArrayCommon< CommandQueueNil >;
    
    public constructor(qs: array of CommandQueueBase; last: CommandQueueNil);
    begin
      data.qs := qs;
      data.last := last;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public function GetQS: sequence of CommandQueueBase := data.GetQS;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    data.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    data.ToString(sb, tabs, index, delayed);
    
  end;
  
  SimpleSyncQueueArrayNil = sealed class(SimpleQueueArrayNil, ISimpleSyncQueueArray)
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override :=
    data.InvokeSync(g, l, data.last.InvokeToNil);
  end;
  SimpleAsyncQueueArrayNil = sealed class(SimpleQueueArrayNil, ISimpleAsyncQueueArray)
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override :=
    new QueueResNil(new CLTaskLocalData( data.InvokeAsync(g, l, data.last.InvokeToNil).Item2 ));
  end;
  
  SimpleQueueArray<T> = abstract class(CommandQueue<T>, ISimpleQueueArray)
    protected data := new SimpleQueueArrayCommon< CommandQueue<T> >;
    
    public constructor(qs: array of CommandQueueBase; last: CommandQueue<T>);
    begin
      data.qs := qs;
      data.last := last;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public function GetQS: sequence of CommandQueueBase := data.GetQS;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    data.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    data.ToString(sb, tabs, index, delayed);
    
  end;
  
  SimpleSyncQueueArray<T> = sealed class(SimpleQueueArray<T>, ISimpleSyncQueueArray)
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;    override := data.InvokeSync(g, l, data.last.InvokeToNil);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := data.InvokeSync(g, l, data.last.InvokeToVal);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := data.InvokeSync(g, l, data.last.InvokeToPtr);
    
  end;
  SimpleAsyncQueueArray<T> = sealed class(SimpleQueueArray<T>, ISimpleAsyncQueueArray)
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override :=
    new QueueResNil(new CLTaskLocalData( data.InvokeAsync(g, l, data.last.InvokeToNil).Item2 ));
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      var (prev_qr, ev) := data.InvokeAsync(g, l, data.last.InvokeToAny);
      Result := prev_qr.WrapResult(qr_factory, ev);
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(g, l, qr_ptr_factory);
    
  end;
  
{$endregion Simple}

{$region Conv}

{$region Generic}

type
  
  {$region Background}
  
  {$region Base}
  
  BackgroundConvQueueArrayBase<TInp, TRes, TFunc> = abstract class(BackgroundConvertQueue<array of TInp, TRes>)
  where TFunc: Delegate;
    protected qs: array of CommandQueue<TInp>;
    protected f: TFunc;
    
    public constructor(qs: array of CommandQueue<TInp>; f: TFunc);
    begin
      self.qs := qs;
      self.f := f;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    foreach var q in qs do q.InitBeforeInvoke(g, inited_hubs);
    
    protected [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function CombineQRs(qrs: array of QueueRes<TInp>; l: CLTaskLocalData): QueueResVal<array of TInp>;
    begin
      if qrs.All(qr->qr.IsConst) then
      begin
        var res := qrs.ConvertAll(qr->qr.GetResDirect);
        Result := new QueueResVal<array of TInp>(l, res);
      end else
      begin
        Result := new QueueResVal<array of TInp>(l);
        Result.AddResSetter(c->qrs.ConvertAll(qr->qr.GetResDirect));
      end;
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      foreach var q in qs do
        q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, f);
      sb += #10;
    end;
    
  end;
  
  {$endregion Base}
  
  {$region Sync}
  
  BackgroundConvSyncQueueArrayBase<TInp, TRes, TFunc> = abstract class(BackgroundConvQueueArrayBase<TInp, TRes, TFunc>)
  where TFunc: Delegate;
    
    protected function InvokeSubQs(g: CLTaskGlobalData; l: CLTaskLocalData): QueueRes<array of TInp>; override;
    begin
      var qrs := new QueueRes<TInp>[qs.Length];
      
      for var i := 0 to qs.Length-1 do
      begin
        var qr := qs[i].InvokeToAny(g, l);
        l := qr.base;
        qrs[i] := qr;
      end;
      
      Result := CombineQRs(qrs, l);
      for var i := 0 to qs.Length-1 do
        qrs[i].TransplantActionsNowhere;
    end;
    
  end;
  
  BackgroundConvSyncQueueArray<TInp, TRes> = sealed class(BackgroundConvSyncQueueArrayBase<TInp, TRes, Func<array of TInp, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o);
    
  end;
  BackgroundConvSyncQueueArrayC<TInp, TRes> = sealed class(BackgroundConvSyncQueueArrayBase<TInp, TRes, Func<array of TInp, Context, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o, c);
    
  end;
  
  {$endregion Sync}
  
  {$region Async}
  
  BackgroundConvAsyncQueueArrayBase<TInp, TRes, TFunc> = abstract class(BackgroundConvQueueArrayBase<TInp, TRes, TFunc>)
  where TFunc: Delegate;
    
    protected function InvokeSubQs(g: CLTaskGlobalData; l: CLTaskLocalData): QueueRes<array of TInp>; override;
    begin
      var qrs := new QueueRes<TInp>[qs.Length];
      var evs := new EventList[qs.Length];
      
      g.ParallelInvoke(l, false, qs.Length, invoker->
      for var i := 0 to qs.Length-1 do
      begin
        var qr := invoker.InvokeBranch(qs[i].InvokeToAny);
        qrs[i] := qr;
        evs[i] := qr.AttachInvokeActions(g);
      end);
      
      var res_ev := EventList.Combine(evs);
      Result := CombineQRs(qrs, new CLTaskLocalData(res_ev));
    end;
    
  end;
  
  BackgroundConvAsyncQueueArray<TInp, TRes> = sealed class(BackgroundConvAsyncQueueArrayBase<TInp, TRes, Func<array of TInp, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o);
    
  end;
  BackgroundConvAsyncQueueArrayC<TInp, TRes> = sealed class(BackgroundConvAsyncQueueArrayBase<TInp, TRes, Func<array of TInp, Context, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o, c);
    
  end;
  
  {$endregion Async}
  
  {$endregion Background}
  
  {$region Quick}
  
  {$region Base}
  
  QuickConvQueueArrayBase<TInp, TRes, TFunc> = abstract class(CommandQueue<TRes>)
  where TFunc: Delegate;
    protected qs: array of CommandQueue<TInp>;
    protected f: TFunc;
    
    public constructor(qs: array of CommandQueue<TInp>; f: TFunc);
    begin
      self.qs := qs;
      self.f := f;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    foreach var q in qs do q.InitBeforeInvoke(g, inited_hubs);
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; abstract;
    
    protected [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function CombineQRsNil(qrs: array of QueueRes<TInp>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;
    begin
      Result := new QueueResNil(l);
      var d := QueueResActionUtils.HandlerWrapStrip(g.curr_err_handler, ExecFunc);
      if l.ShouldInstaCallAction then
        d(qrs.ConvertAll(qr->qr.GetResDirect), g.c) else
        Result.AddAction(c->d(qrs.ConvertAll(qr->qr.GetResDirect), c));
    end;
    
    protected [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function CombineQRsRes<TF,TR>(qrs: array of QueueRes<TInp>; g: CLTaskGlobalData; l: CLTaskLocalData): TR; where TF: IQueueResFactory<TRes,TR>, constructor; where TR: QueueRes<TRes>;
    begin
      //TODO #2644: &<>
      var d := QueueResActionUtils.HandlerWrap&<array of TInp, TRes>(g.curr_err_handler, ExecFunc);
      if l.ShouldInstaCallAction then
      begin
        var res := d(qrs.ConvertAll(qr->qr.GetResDirect), g.c);
        Result := TF.Create.MakeConst(l, res);
      end else
      begin
        Result := TF.Create.MakeDelayed(l);
        Result.AddResSetter(c->d(qrs.ConvertAll(qr->qr.GetResDirect), c));
      end;
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      foreach var q in qs do
        q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, f);
      sb += #10;
    end;
    
  end;
  
  {$endregion Base}
  
  {$region Sync}
  
  QuickConvSyncQueueArrayBase<TInp, TRes, TFunc> = abstract class(QuickConvQueueArrayBase<TInp, TRes, TFunc>)
  where TFunc: Delegate;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TF,TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory_sample: TF; CombineQRs: Func<array of QueueRes<TInp>, CLTaskGlobalData, CLTaskLocalData, TR>): TR; where TF: IQueueResBaseFactory<TR>, constructor; where TR: IQueueRes;
    begin
      var qrs := new QueueRes<TInp>[qs.Length];
      
      for var i := 0 to qs.Length-1 do
      begin
        var qr := qs[i].InvokeToAny(g, l);
        l := qr.base;
        qrs[i] := qr;
      end;
      
      Result := CombineQRs(qrs, g, l);
      for var i := 0 to qs.Length-1 do
        qrs[i].TransplantActionsNowhere;
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;       override := Invoke(g, l, qr_nil_factory, CombineQRsNil);
    //TODO #????
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override := Invoke&<QueueResValFactory<TRes>,QueueResVal<TRes>>(g, l, qr_val_factory, CombineQRsRes&<QueueResValFactory<TRes>,QueueResVal<TRes>>);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := Invoke&<QueueResPtrFactory<TRes>,QueueResPtr<TRes>>(g, l, qr_ptr_factory, CombineQRsRes&<QueueResPtrFactory<TRes>,QueueResPtr<TRes>>);
    
  end;
  
  QuickConvSyncQueueArray<TInp, TRes> = sealed class(QuickConvSyncQueueArrayBase<TInp, TRes, Func<array of TInp, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o);
    
  end;
  QuickConvSyncQueueArrayC<TInp, TRes> = sealed class(QuickConvSyncQueueArrayBase<TInp, TRes, Func<array of TInp, Context, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o, c);
    
  end;
  
  {$endregion Sync}
  
  {$region Async}
  
  QuickConvAsyncQueueArrayBase<TInp, TRes, TFunc> = abstract class(QuickConvQueueArrayBase<TInp, TRes, TFunc>)
  where TFunc: Delegate;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TF,TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory_sample: TF; CombineQRs: Func<array of QueueRes<TInp>, CLTaskGlobalData, CLTaskLocalData, TR>): TR; where TF: IQueueResBaseFactory<TR>, constructor; where TR: IQueueRes;
    begin
      var qrs := new QueueRes<TInp>[qs.Length];
      var evs := new EventList[qs.Length];
      
      g.ParallelInvoke(l, false, qs.Length, invoker->
      for var i := 0 to qs.Length-1 do
      begin
        var qr := invoker.InvokeBranch(qs[i].InvokeToAny);
        evs[i] := qr.AttachInvokeActions(g);
        qrs[i] := qr;
      end);
      
      var res_ev := EventList.Combine(evs);
      Result := CombineQRs(qrs, g, new CLTaskLocalData(res_ev));
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;       override := Invoke(g, l, qr_nil_factory, CombineQRsNil);
    //TODO #????
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override := Invoke&<QueueResValFactory<TRes>,QueueResVal<TRes>>(g, l, qr_val_factory, CombineQRsRes&<QueueResValFactory<TRes>,QueueResVal<TRes>>);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := Invoke&<QueueResPtrFactory<TRes>,QueueResPtr<TRes>>(g, l, qr_ptr_factory, CombineQRsRes&<QueueResPtrFactory<TRes>,QueueResPtr<TRes>>);
    
  end;
  
  QuickConvAsyncQueueArray<TInp, TRes> = sealed class(QuickConvAsyncQueueArrayBase<TInp, TRes, Func<array of TInp, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o);
    
  end;
  QuickConvAsyncQueueArrayC<TInp, TRes> = sealed class(QuickConvAsyncQueueArrayBase<TInp, TRes, Func<array of TInp, Context, TRes>>)
    
    protected function ExecFunc(o: array of TInp; c: Context): TRes; override := f(o, c);
    
  end;
  
  {$endregion Async}
  
  {$endregion Quick}
  
{$endregion Generic}

{%ConvQueue\AllStaticArrays!ConvQueueStaticArray.pas%}

{$endregion Conv}

{$region Utils}

type
  QueueArrayFlattener<TArray> = sealed class(ITypedCQUser)
  where TArray: ISimpleQueueArray;
    public qs := new List<CommandQueueBase>;
    private has_next := false;
    
    public procedure ProcessSeq(s: sequence of CommandQueueBase);
    begin
      var enmr := s.GetEnumerator;
      if not enmr.MoveNext then raise new System.ArgumentException('%Err:FlattenQueueArray:InpEmpty%');
      
      var upper_had_next := self.has_next;
      while true do
      begin
        var curr := enmr.Current;
        var l_has_next := enmr.MoveNext;
        self.has_next := upper_had_next or l_has_next;
        curr.UseTyped(self);
        if not l_has_next then break;
      end;
      self.has_next := upper_had_next;
      
    end;
    
    public procedure ITypedCQUser.UseNil(cq: CommandQueueNil);
    begin
      // Нельзя пропускать - тут можно быть HPQ, WaitFor и т.п. работа без результата
//      if has_next then exit;
      qs.Add(cq);
    end;
    public procedure ITypedCQUser.Use<T>(cq: CommandQueue<T>);
    begin
      if has_next then
      begin
        if cq is ConstQueue<T> then exit;
        if cq is ParameterQueue<T> then exit;
        if cq is CastQueueBase<T>(var cqb) then
        begin
          cqb.SourceBase.UseTyped(self);
          exit;
        end;
      end;
      if cq is TArray(var sqa) then
        ProcessSeq(sqa.GetQs) else
        qs.Add(cq);
    end;
    
  end;
  
  QueueArrayConstructorBase = abstract class
    private body: array of CommandQueueBase;
    
    public constructor(body: array of CommandQueueBase) := self.body := body;
    private constructor := raise new OpenCLABCInternalException;
    
  end;
  
  QueueArraySyncConstructor = sealed class(QueueArrayConstructorBase, ITypedCQConverter<CommandQueueBase>)
    public function ConvertNil(last: CommandQueueNil): CommandQueueBase := new SimpleSyncQueueArrayNil(body, last);
    public function Convert<T>(last: CommandQueue<T>): CommandQueueBase := new SimpleSyncQueueArray<T>(body, last);
  end;
  QueueArrayAsyncConstructor = sealed class(QueueArrayConstructorBase, ITypedCQConverter<CommandQueueBase>)
    public function ConvertNil(last: CommandQueueNil): CommandQueueBase := new SimpleAsyncQueueArrayNil(body, last);
    public function Convert<T>(last: CommandQueue<T>): CommandQueueBase := new SimpleAsyncQueueArray<T>(body, last);
  end;
  
  QueueArrayUtils = static class
    
    public static function FlattenQueueArray<T>(inp: sequence of CommandQueueBase): ValueTuple<List<CommandQueueBase>,CommandQueueBase>; where T: ISimpleQueueArray;
    begin
      var res := new QueueArrayFlattener<T>;
      res.ProcessSeq(inp);
      var last_ind := res.qs.Count-1;
      var last := res.qs[last_ind];
      res.qs.RemoveAt(last_ind);
      Result := ValueTuple.Create(res.qs,last);
    end;
    
    public static function ConstructSync(inp: sequence of CommandQueueBase): CommandQueueBase;
    begin
      var (body,last) := FlattenQueueArray&<ISimpleSyncQueueArray>(inp);
      Result := if body.Count=0 then last else last.ConvertTyped(new QueueArraySyncConstructor(body.ToArray));
    end;
    public static function ConstructSyncNil(inp: sequence of CommandQueueBase) := CommandQueueNil ( ConstructSync(inp) );
    public static function ConstructSync<T>(inp: sequence of CommandQueueBase) := CommandQueue&<T>( ConstructSync(inp) );
    
    public static function ConstructAsync(inp: sequence of CommandQueueBase): CommandQueueBase;
    begin
      var (body,last) := FlattenQueueArray&<ISimpleAsyncQueueArray>(inp);
      Result := if body.Count=0 then last else last.ConvertTyped(new QueueArrayAsyncConstructor(body.ToArray));
    end;
    public static function ConstructAsyncNil(inp: sequence of CommandQueueBase) := CommandQueueNil ( ConstructAsync(inp) );
    public static function ConstructAsync<T>(inp: sequence of CommandQueueBase) := CommandQueue&<T>( ConstructAsync(inp) );
    
  end;
  
{$endregion Utils}

static function CommandQueueNil.operator+(q1: CommandQueueBase; q2: CommandQueueNil) := QueueArrayUtils. ConstructSyncNil(|q1, q2|);
static function CommandQueueNil.operator*(q1: CommandQueueBase; q2: CommandQueueNil) := QueueArrayUtils.ConstructAsyncNil(|q1, q2|);

static function CommandQueue<T>.operator+(q1: CommandQueueBase; q2: CommandQueue<T>) := QueueArrayUtils. ConstructSync&<T>(|q1, q2|);
static function CommandQueue<T>.operator*(q1: CommandQueueBase; q2: CommandQueue<T>) := QueueArrayUtils.ConstructAsync&<T>(|q1, q2|);

{$endregion +/*}

{$region Multiusable}

type
  MultiusableCommandQueueHubCommon<TQ> = abstract class(IMultiusableCommandQueueHub)
  where TQ: CommandQueueBase;
    public q: TQ;
    public constructor(q: TQ) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>) :=
    if inited_hubs.Add(self) then q.InitBeforeInvoke(g, inited_hubs);
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; invoke_q: CommandQueueInvoker<TR>): ValueTuple<TR, EventList>; where TR: IQueueRes;
    begin
      var res_data: MultiuseableResultData;
      var qr: TR;
      
      // Потоко-безопасно, потому что все .Invoke выполняются синхронно
      //TODO А что будет когда .ThenIf и т.п.?
      if g.mu_res.TryGetValue(self, res_data) then
        qr := TR(res_data.qres) else
      begin
        var prev_err_handler := g.curr_err_handler;
        g.curr_err_handler := new CLTaskErrHandlerEmpty;
        
        qr := invoke_q(g, new CLTaskLocalData);
        var ev := qr.AttachInvokeActions(g);
        
        res_data := new MultiuseableResultData(qr, ev, g.curr_err_handler);
        g.mu_res[self] := res_data;
        
        g.curr_err_handler := prev_err_handler;
      end;
      g.curr_err_handler := new CLTaskErrHandlerThiefRepeater(g.curr_err_handler, res_data.err_handler);
      
      res_data.ev.Retain({$ifdef EventDebug}$'for all mu branches'{$endif});
      Result := ValueTuple.Create( qr, res_data.ev + QueueResNil.Create(l).AttachInvokeActions(g) );
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>);
    begin
      sb += ' => ';
      if q.ToStringHeader(sb, index) then
        delayed.Add(q);
      sb += #10;
    end;
    
  end;
  
  MultiusableCommandQueueHubNil = sealed partial class(MultiusableCommandQueueHubCommon< CommandQueueNil >) end;
  MultiusableCommandQueueNodeNil = sealed class(CommandQueueNil)
    public hub: MultiusableCommandQueueHubNil;
    
    public constructor(hub: MultiusableCommandQueueHubNil) := self.hub := hub;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := hub.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var (qr, ev) := hub.Invoke(g, l, hub.q.InvokeToNil);
      Result := new QueueResNil(new CLTaskLocalData(ev));
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    hub.ToString(sb, tabs, index, delayed);
    
  end;
  MultiusableCommandQueueHubNil = sealed partial class
    
    public function MakeNode: CommandQueueNil := new MultiusableCommandQueueNodeNil(self);
    
  end;
  
  MultiusableCommandQueueHub<T> = sealed partial class(MultiusableCommandQueueHubCommon< CommandQueue<T> >) end;
  MultiusableCommandQueueNode<T> = sealed class(CommandQueue<T>)
    public hub: MultiusableCommandQueueHub<T>;
    
    public constructor(hub: MultiusableCommandQueueHub<T>) := self.hub := hub;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := hub.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var (qr, ev) := hub.Invoke(g, l, hub.q.InvokeToNil);
      Result := new QueueResNil(new CLTaskLocalData(ev));
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<T, TR>): TR; where TR: QueueRes<T>;
    begin
      var (qr, ev) := hub.Invoke(g, l, hub.q.InvokeToVal);
      Result := qr.WrapResult(qr_factory, ev);
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(g, l, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    hub.ToString(sb, tabs, index, delayed);
    
  end;
  MultiusableCommandQueueHub<T> = sealed partial class
    
    public function MakeNode: CommandQueue<T> := new MultiusableCommandQueueNode<T>(self);
    
  end;
  
function CommandQueueNil.Multiusable: ()->CommandQueueNil := (if self is MultiusableCommandQueueNodeNil(var mucqn) then mucqn.hub else new MultiusableCommandQueueHubNil(self)).MakeNode;
function CommandQueue<T>.Multiusable: ()->CommandQueue<T> := (if self is MultiusableCommandQueueNode<T>(var mucqn) then mucqn.hub else new MultiusableCommandQueueHub<T>(self)).MakeNode;

{$endregion Multiusable}

{$region Wait}

{$region Def}
//TODO Куча дублей кода, особенно в Combination
//TODO data ничего не делает, кроме как для WaitDebug, потому что state хранится в sub_info
// - Лучше передавать self.GetHashCode
//TODO Отписка никогда не происходит - пока не сделал, чтоб перепродумывать как обрабатывать всё при циклах

{$region Base}

type
  WaitMarker = abstract partial class
    
    public procedure InitInnerHandles(g: CLTaskGlobalData); abstract;
    
    public function MakeWaitEv(g: CLTaskGlobalData; prev_ev: EventList): EventList; abstract;
    public function MakeWaitEv(g: CLTaskGlobalData; l: CLTaskLocalData) := MakeWaitEv(g, QueueResNil.Create(l).AttachInvokeActions(g));
    
  end;
  
{$endregion Base}

{$region Outer}

type
  /// wait_handler, который можно встроить в очередь как есть
  WaitHandlerOuter = abstract class
    public uev: UserEvent;
    private state := 0;
    private gc_hnd: GCHandle;
    
    public constructor(g: CLTaskGlobalData; prev_ev: EventList);
    begin
      
      uev := new UserEvent(g.cl_c{$ifdef EventDebug}, $'Wait result'{$endif});
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Created outer with prev_ev=[ {prev_ev.evs?.JoinToString} ], res_ev={uev}');
      {$endif WaitDebug}
      self.gc_hnd := GCHandle.Alloc(self);
      
      // Code of .ThenFinallyWaitFor expects
      // g.curr_err_handler to not change
      // and no new errors to be added
      var err_handler := g.curr_err_handler;
      prev_ev.MultiAttachCallback(()->
      begin
        if err_handler.HadError(true) then
        begin
          {$ifdef WaitDebug}
          WaitDebug.RegisterAction(self, $'Aborted');
          {$endif WaitDebug}
          uev.SetComplete;
          self.gc_hnd.Free;
        end else
        begin
          {$ifdef WaitDebug}
          WaitDebug.RegisterAction(self, $'Got prev_ev boost');
          {$endif WaitDebug}
          self.IncState;
        end;
      end{$ifdef EventDebug}, $'KeepAlive(handler[{self.GetHashCode}])'{$endif});
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function TryConsume: boolean; abstract;
    
    protected function IncState: boolean;
    begin
      var new_state := Interlocked.Increment(self.state);
      
      {$ifdef DEBUG}
      if not new_state.InRange(1,2) then raise new OpenCLABCInternalException($'WaitHandlerOuter.state={new_state}');
      {$endif DEBUG}
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Advanced to state {new_state}');
      {$endif WaitDebug}
      
      Result := (new_state=2) and TryConsume;
      if Result then self.gc_hnd.Free;
    end;
    protected procedure DecState;
    begin
      {$ifdef DEBUG}
      var new_state :=
      {$endif DEBUG}
      Interlocked.Decrement(self.state);
      
      {$ifdef DEBUG}
      if not new_state.InRange(0,1) then
        raise new OpenCLABCInternalException($'WaitHandlerOuter.state={new_state}');
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Gone back to state {new_state}');
      {$endif WaitDebug}
      
      {$endif DEBUG}
      
    end;
    
  end;
  
{$endregion Outer}

{$region Direct}

type
  IWaitHandlerSub = interface
    
    // Возвращает true, если активацию успешно съели
    function HandleChildInc(data: integer): boolean;
    procedure HandleChildDec(data: integer);
    
  end;
  
  WaitHandlerDirectSubInfo = class
    public threshold, data: integer;
    public state := new InterlockedBoolean;
    public constructor(threshold, data: integer);
    begin
      self.threshold := threshold;
      self.data := data;
    end;
    public constructor := raise new OpenCLABCInternalException;
  end;
  /// Напрямую хранит активации конкретного CLTaskGlobalData
  WaitHandlerDirect = sealed class
    private subs := new ConcurrentDictionary<IWaitHandlerSub, WaitHandlerDirectSubInfo>;
    private activations := 0;
    private reserved := 0;
    
    public procedure Subscribe(sub: IWaitHandlerSub; info: WaitHandlerDirectSubInfo);
    begin
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got new sub {sub.GetHashCode}');
      {$endif WaitDebug}
      
      if not subs.TryAdd(sub, info) then
      begin
        {$ifdef DEBUG}
        raise new OpenCLABCInternalException($'Sub added twice');
        {$endif DEBUG}
      end else
      if activations>=info.threshold then
        if info.state.TrySet(true) then
        begin
          {$ifdef WaitDebug}
          WaitDebug.RegisterAction(self, $'Add immidiatly inced sub {sub.GetHashCode}');
          {$endif WaitDebug}
          // Может выполняться одновременно с AddActivation, в таком случае 
          sub.HandleChildInc(info.data);
        end;
    end;
    
    public procedure AddActivation;
    begin
      {$ifdef WaitDebug}
      var new_act :=
      {$endif WaitDebug}
      Interlocked.Increment(activations);
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got activation =>{new_act}');
      {$endif WaitDebug}
      
      foreach var kvp in subs do
        // activations может изменится, если .HandleChildInc из
        // .AddActivation другого хэндлера или .Subscribe затронет self.activations
        // Поэтому результат Interlocked.Increment использовать нельзя
        if activations>=kvp.Value.threshold then
          if kvp.Value.state.TrySet(true) and kvp.Key.HandleChildInc(kvp.Value.data) then
          begin
            {$ifdef WaitDebug}
            WaitDebug.RegisterAction(self, $'Sub {kvp.Key.GetHashCode} consumed activation =>{activations}');
            {$endif WaitDebug}
            // Если активацию съели - нет смысла продолжать
            break;
          end;
    end;
    
    public function TryReserve(c: integer): boolean;
    begin
      var n_reserved := Interlocked.Add(reserved, c);
      Result := n_reserved<=activations;
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Tried to reserve {c}=>{n_reserved}: {Result}');
      {$endif WaitDebug}
      
      // Надо делать там, где было вызвано TryReserve
      // Потому что TryReserve не последняя проверка, есть ещё uev.SetStatus
//      if not Result then ReleaseReserve(c);
    end;
    public procedure ReleaseReserve(c: integer) :=
    if Interlocked.Add(reserved, -c)<0 then
    begin
      {$ifdef DEBUG}
      raise new OpenCLABCInternalException($'reserved={reserved}');
      {$endif DEBUG}
    end else
    begin
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Released reserve {c}=>{reserved}');
      {$endif WaitDebug}
    end;
    
    public procedure Comsume(c: integer);
    begin
      var new_act := Interlocked.Add(activations, -c);
      var new_res := Interlocked.Add(reserved, -c);
      {$ifdef DEBUG}
      if (new_act<0) or (new_res<0) then
        raise new OpenCLABCInternalException($'new_act={new_act}, new_res={new_res}');
      {$endif DEBUG}
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Sub consumed {c}, new_act={new_act}, new_res={new_res}');
      {$endif WaitDebug}
      
      foreach var kvp in subs do
        if activations<kvp.Value.threshold then
          if kvp.Value.state.TrySet(false) then
            kvp.Key.HandleChildDec(kvp.Value.data);
    end;
    
  end;
  /// Обёртка WaitHandlerDirect, которая является WaitHandlerOuter
  WaitHandlerDirectWrap = sealed class(WaitHandlerOuter, IWaitHandlerSub)
    private source: WaitHandlerDirect;
    
    public constructor(g: CLTaskGlobalData; prev_ev: EventList; source: WaitHandlerDirect);
    begin
      inherited Create(g, prev_ev);
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'This is DirectWrap for {source.GetHashCode}');
      {$endif WaitDebug}
      self.source := source;
      source.Subscribe(self, new WaitHandlerDirectSubInfo(1,0));
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public function IWaitHandlerSub.HandleChildInc(data: integer) := self.IncState;
    public procedure IWaitHandlerSub.HandleChildDec(data: integer) := self.DecState;
    
    protected function TryConsume: boolean; override;
    begin
      Result := source.TryReserve(1) and self.uev.SetComplete;
      if not Result then source.ReleaseReserve(1);
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Tried reserving {1} in source[{source.GetHashCode}]: {Result}');
      {$endif WaitDebug}
      
      if Result then source.Comsume(1);
    end;
    
  end;
  
  /// Маркер, не ссылающийся на другие маркеры
  WaitMarkerDirect = abstract class(WaitMarker)
    private handlers := new ConcurrentDictionary<CLTaskGlobalData, WaitHandlerDirect>;
    
    public procedure InitInnerHandles(g: CLTaskGlobalData); override :=
    handlers.GetOrAdd(g, g->
    begin
      Result := new WaitHandlerDirect;
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(Result, $'Created for {self.GetType.Name}[{self.GetHashCode}]');
      {$endif WaitDebug}
    end);
    
    public function MakeWaitEv(g: CLTaskGlobalData; prev_ev: EventList): EventList; override :=
    WaitHandlerDirectWrap.Create(g, prev_ev, handlers[g]).uev;
    
    public procedure SendSignal; override :=
    foreach var h in handlers.Values do
      h.AddActivation;
    
  end;
  
{$endregion Direct}

{$region Combination}

{$region Base}

type
  WaitMarkerCombination<TChild> = abstract class(WaitMarker)
  where TChild: WaitMarker;
    private children: array of TChild;
    
    public constructor(children: array of TChild) := self.children := children;
    public constructor := raise new OpenCLABCInternalException;
    
    public procedure InitInnerHandles(g: CLTaskGlobalData); override :=
    foreach var child in children do child.InitInnerHandles(g);
    
    {$region Disabled override's}
    
    private function ConvertToQBase: CommandQueueBase; override;
    begin
      Result := nil;
      raise new System.InvalidProgramException($'%Err:WaitMarkerCombination.ConvertToQBase%');
    end;
    
    public procedure SendSignal; override :=
    raise new System.InvalidProgramException($'Err:WaitMarkerCombination.SendSignal');
    
    {$endregion Disabled override's}
    
  end;
  
{$endregion Base}

{$region All}

type
  WaitHandlerAllInner<TSub> = sealed class(IWaitHandlerSub)
  where TSub: IWaitHandlerSub;
    private sources: array of WaitHandlerDirect;
    private ref_counts: array of integer;
    private done_c := 0;
    
    private sub: TSub;
    private sub_data: integer;
    
    public constructor(sources: array of WaitHandlerDirect; ref_counts: array of integer; sub: TSub; sub_data: integer);
    begin
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Created AllInner for: {sources.Select(s->s.GetHashCode).JoinToString}');
      {$endif WaitDebug}
      self.sources := sources;
      for var i := 0 to sources.Length-1 do
        sources[i].Subscribe(self, new WaitHandlerDirectSubInfo(ref_counts[i], i));
      self.ref_counts := ref_counts;
      self.sub := sub;
      self.sub_data := sub_data;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public function IWaitHandlerSub.HandleChildInc(data: integer): boolean;
    begin
      var new_done_c := Interlocked.Increment(done_c);
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got activation from {sources[data].GetHashCode}, new_done_c={new_done_c}/{sources.Length}');
      {$endif WaitDebug}
      
      Result := (new_done_c=sources.Length) and sub.HandleChildInc(sub_data);
    end;
    public procedure IWaitHandlerSub.HandleChildDec(data: integer);
    begin
      var prev_done_c := Interlocked.Decrement(done_c)+1;
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got deactivation from {sources[data].GetHashCode}, new_done_c={prev_done_c-1}/{sources.Length}');
      {$endif WaitDebug}
      
      if prev_done_c=sources.Length then sub.HandleChildDec(sub_data);
    end;
    
    public function TryConsume(uev: UserEvent): boolean;
    begin
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Trying to reserve');
      {$endif WaitDebug}
      Result := false;
      for var i := 0 to sources.Length-1 do
      begin
        if sources[i].TryReserve(ref_counts[i]) then continue;
        for var prev_i := 0 to i do
          sources[i].ReleaseReserve(ref_counts[i]);
        exit;
      end;
      Result := uev.SetComplete;
      if Result then
      begin
        {$ifdef WaitDebug}
        WaitDebug.RegisterAction(self, $'Consuming');
        {$endif WaitDebug}
        for var i := 0 to sources.Length-1 do
          sources[i].Comsume(ref_counts[i]);
      end else
      begin
        {$ifdef WaitDebug}
        WaitDebug.RegisterAction(self, $'Abort consume');
        {$endif WaitDebug}
        for var i := 0 to sources.Length-1 do
          sources[i].ReleaseReserve(ref_counts[i]);
      end;
    end;
    
  end;
  WaitHandlerAllOuter = sealed class(WaitHandlerOuter, IWaitHandlerSub)
    private sources: array of WaitHandlerDirect;
    private ref_counts: array of integer;
    private done_c := 0;
    
    public constructor(g: CLTaskGlobalData; prev_ev: EventList; sources: array of WaitHandlerDirect; ref_counts: array of integer);
    begin
      inherited Create(g, prev_ev);
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'This is AllOuter for: {sources.Select(s->s.GetHashCode).JoinToString}');
      {$endif WaitDebug}
      self.sources := sources;
      for var i := 0 to sources.Length-1 do
        sources[i].Subscribe(self, new WaitHandlerDirectSubInfo(ref_counts[i], i));
      self.ref_counts := ref_counts;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public function IWaitHandlerSub.HandleChildInc(data: integer): boolean;
    begin
      var new_done_c := Interlocked.Increment(done_c);
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got activation from {sources[data].GetHashCode}, new_done_c={new_done_c}/{sources.Length}');
      {$endif WaitDebug}
      
      Result := (new_done_c=sources.Length) and self.IncState;
    end;
    public procedure IWaitHandlerSub.HandleChildDec(data: integer);
    begin
      var prev_done_c := Interlocked.Decrement(done_c)+1;
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got deactivation from {sources[data].GetHashCode}, new_done_c={prev_done_c-1}/{sources.Length}');
      {$endif WaitDebug}
      
      if prev_done_c=sources.Length then self.DecState;
    end;
    
    protected function TryConsume: boolean; override;
    begin
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Trying to reserve');
      {$endif WaitDebug}
      Result := false;
      for var i := 0 to sources.Length-1 do
      begin
        if sources[i].TryReserve(ref_counts[i]) then continue;
        for var prev_i := 0 to i do
          sources[i].ReleaseReserve(ref_counts[i]);
        exit;
      end;
      Result := uev.SetComplete;
      if Result then
      begin
        {$ifdef WaitDebug}
        WaitDebug.RegisterAction(self, $'Consuming');
        {$endif WaitDebug}
        for var i := 0 to sources.Length-1 do
          sources[i].Comsume(ref_counts[i]);
      end else
      begin
        {$ifdef WaitDebug}
        WaitDebug.RegisterAction(self, $'Abort consume');
        {$endif WaitDebug}
        for var i := 0 to sources.Length-1 do
          sources[i].ReleaseReserve(ref_counts[i]);
      end;
    end;
    
  end;
  
  WaitMarkerAll = sealed partial class(WaitMarkerCombination<WaitMarkerDirect>)
    private ref_counts: array of integer;
    
    public constructor(children: Dictionary<WaitMarkerDirect, integer>);
    begin
      inherited Create(children.Keys.ToArray);
      self.ref_counts := self.children.ConvertAll(key->children[key]);
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      foreach var i in Range(0,children.Length-1).OrderByDescending(i->ref_counts[i]) do
      begin
        children[i].ToString(sb, tabs, index, delayed);
        if ref_counts[i]<>1 then
        begin
          sb.Length -= 1;
          sb += ' * ';
          sb.Append(ref_counts[i]);
          sb += #10;
        end;
      end;
    end;
    
    public function MakeWaitEv(g: CLTaskGlobalData; prev_ev: EventList): EventList; override :=
    WaitHandlerAllOuter.Create(g, prev_ev, children.ConvertAll(m->m.handlers[g]), ref_counts).uev;
    
    private function GetChildrenArr: array of WaitMarkerDirect;
    begin
      Result := new WaitMarkerDirect[ref_counts.Sum];
      var res_ind := 0;
      for var i := 0 to children.Length-1 do
        loop ref_counts[i] do
        begin
          Result[res_ind] := children[i];
          res_ind += 1;
        end;
    end;
    
  end;
  
{$endregion All}

{$region Any}

type
  WaitHandlerAnyOuter = sealed class(WaitHandlerOuter, IWaitHandlerSub)
    private sources: array of WaitHandlerAllInner<WaitHandlerAnyOuter>;
    
    private done_c := 0;
    
    public constructor(g: CLTaskGlobalData; prev_ev: EventList; markers: array of WaitMarkerAll);
    begin
      inherited Create(g, prev_ev);
      self.sources := new WaitHandlerAllInner<WaitHandlerAnyOuter>[markers.Length];
      for var i := 0 to markers.Length-1 do
        self.sources[i] := new WaitHandlerAllInner<WaitHandlerAnyOuter>(markers[i].children.ConvertAll(m->m.handlers[g]), markers[i].ref_counts, self, i);
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'This is AnyOuter for: {sources.Select(s->s.GetHashCode).JoinToString}');
      {$endif WaitDebug}
    end;
    public constructor := raise new OpenCLABCInternalException;
    
    public function IWaitHandlerSub.HandleChildInc(data: integer): boolean;
    begin
      var new_done_c := Interlocked.Increment(done_c);
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got activation from {sources[data].GetHashCode}, new_done_c={new_done_c}/{sources.Length}');
      {$endif WaitDebug}
      
      Result := (new_done_c=1) and self.IncState;
    end;
    public procedure IWaitHandlerSub.HandleChildDec(data: integer);
    begin
      var prev_done_c := Interlocked.Decrement(done_c)+1;
      
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Got deactivation from {sources[data].GetHashCode}, new_done_c={prev_done_c-1}/{sources.Length}');
      {$endif WaitDebug}
      
      if prev_done_c=1 then self.DecState;
    end;
    
    protected function TryConsume: boolean; override;
    begin
      {$ifdef WaitDebug}
      WaitDebug.RegisterAction(self, $'Trying to consume');
      {$endif WaitDebug}
      Result := false;
      for var i := 0 to sources.Length-1 do
        if sources[i].TryConsume(uev) then
        begin
          Result := true;
          break;
        end;
    end;
    
  end;
  
  WaitMarkerAny = sealed partial class(WaitMarkerCombination<WaitMarkerAll>)
    
    public constructor(sources: array of WaitMarkerAll) := inherited Create(sources);
    private constructor := raise new OpenCLABCInternalException;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      foreach var child in children do
        child.ToString(sb, tabs, index, delayed);
    end;
    
    public function MakeWaitEv(g: CLTaskGlobalData; prev_ev: EventList): EventList; override :=
    WaitHandlerAnyOuter.Create(g, prev_ev, children).uev;
    
  end;
  
{$endregion Any}

{$region public}

type
  WaitMarkerAllFast = sealed class
    private children: Dictionary<WaitMarkerDirect, integer>;
    
    public constructor(c: integer) :=
    children := new Dictionary<WaitMarkerDirect, integer>(c);
    public constructor(m: WaitMarkerDirect);
    begin
      Create(1);
      self.children.Add(m, 1);
    end;
    public constructor(m: WaitMarkerAll);
    begin
      Create(m.children.Length);
      for var i := 0 to m.children.Length-1 do
        self.children.Add(m.children[i], m.ref_counts[i]);
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public static function operator in(what, in_what: WaitMarkerAllFast): boolean;
    begin
      Result := false;
      
      if what.children.Count>in_what.children.Count then
        exit;
      foreach var kvp in what.children do
        if in_what.children.Get(kvp.Key) < kvp.Value then
          exit;
      
      Result := true;
    end;
    
    public static function operator+(c1, c2: WaitMarkerAllFast): WaitMarkerAllFast;
    begin
      Result := new WaitMarkerAllFast(c1.children.Count+c2.children.Count);
      foreach var kvp in c1.children do
        Result.children.Add(kvp.Key, kvp.Value);
      foreach var kvp in c2.children do
        Result.children[kvp.Key] := Result.children.Get(kvp.Key) + kvp.Value;
    end;
    
    public static procedure TryAdd(lst: List<WaitMarkerAllFast>; c: WaitMarkerAllFast);
    begin
      
      for var i := 0 to lst.Count-1 do
      begin
        var c0 := lst[i];
        
        if c0 in c then
          lst[i] := c else
        if c in c0 then
          {nothing} else
          continue;
        
        exit;
      end;
      
      lst += c;
    end;
    
    public static function MarkerFromLst(lst: IList<WaitMarkerAllFast>): WaitMarker;
    begin
      if lst.Count>1 then
      begin
        var res := new WaitMarkerAll[lst.Count];
        for var i := 0 to res.Length-1 do
          res[i] := new WaitMarkerAll(lst[i].children);
        Result := new WaitMarkerAny(res);
      end else
      case lst[0].children.Values.Sum of
        0: raise new System.ArgumentException($'%Err:WaitCombine:InpEmpty%');
        1: Result := lst[0].children.Keys.Single;
        else Result := new WaitMarkerAll(lst[0].children);
      end;
    end;
    
  end;
  
function WaitAll(sub_markers: sequence of WaitMarker): WaitMarker;
begin
  var prev := |new WaitMarkerAllFast(0)| as IList<WaitMarkerAllFast>;
  var next := new List<WaitMarkerAllFast>;
  
  foreach var m in sub_markers do
  begin
    
    if m is WaitMarkerAny(var ma) then
    begin
      foreach var child in ma.children do
      begin
        var c2 := new WaitMarkerAllFast(child);
        foreach var c1 in prev do
          WaitMarkerAllFast.TryAdd(next, c1+c2);
      end;
    end else
    begin
      var c2 := if m is WaitMarkerDirect(var md) then
        new WaitMarkerAllFast(md) else
        new WaitMarkerAllFast(WaitMarkerAll(m));
      foreach var c1 in prev do
        next += c1+c2;
    end;
    
    prev := next.ToArray;
    next.Clear;
  end;
  
  Result := WaitMarkerAllFast.MarkerFromLst(prev);
end;
function WaitAll(params sub_markers: array of WaitMarker) := WaitAll(sub_markers.AsEnumerable);

function WaitAny(sub_markers: sequence of WaitMarker): WaitMarker;
begin
  var res := new List<WaitMarkerAllFast>;
  foreach var m in sub_markers do
    if m is WaitMarkerAny(var ma) then
    begin
      foreach var child in ma.children do
        WaitMarkerAllFast.TryAdd(res, new WaitMarkerAllFast(child));
    end else
    begin
      var c := if m is WaitMarkerDirect(var md) then
        new WaitMarkerAllFast(md) else
        new WaitMarkerAllFast(WaitMarkerAll(m));
      WaitMarkerAllFast.TryAdd(res, c);
    end;
  Result := WaitMarkerAllFast.MarkerFromLst(res);
end;
function WaitAny(params sub_markers: array of WaitMarker) := WaitAny(sub_markers.AsEnumerable);

static function WaitMarker.operator and(m1, m2: WaitMarker) := WaitAll(|m1, m2|);
static function WaitMarker.operator or(m1, m2: WaitMarker) := WaitAny(|m1, m2|);

{$endregion public}

{$endregion Combination}

{$endregion Def}

{$region WaitMarkerDummy}

type
  WaitMarkerDummyExecutor = sealed class(CommandQueueNil)
    private m: WaitMarkerDirect;
    
    public constructor(m: WaitMarkerDirect) := self.m := m;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      Result := new QueueResNil(l);
      
      var err_handler := g.curr_err_handler;
      Result.AddAction(c->if not err_handler.HadError(true) then m.SendSignal);
      
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      m.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  WaitMarkerDummy = sealed class(WaitMarkerDirect)
    private executor: WaitMarkerDummyExecutor;
    public constructor := executor := new WaitMarkerDummyExecutor(self);
    
    private function ConvertToQBase: CommandQueueBase; override := executor;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override := sb += #10;
    
  end;
  
static function WaitMarker.Create := new WaitMarkerDummy;

{$endregion WaitMarkerDummy}

{$region ThenMarkerSignal}

type
  DetachedMarkerSignalWrapCommon<TQ> = abstract class(WaitMarkerDirect)
  where TQ: CommandQueueBase;
    protected org: TQ;
    
    public constructor(org: TQ) := self.org := org;
    private constructor := raise new OpenCLABCInternalException;
    
    private function ConvertToQBase: CommandQueueBase; override := org;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      sb.Append(#9, tabs);
      org.ToStringHeader(sb, index);
      sb += #10;
      
    end;
    
  end;
  
  DetachedMarkerSignalCommon<TQ> = record
  where TQ: CommandQueueBase;
    public q: TQ;
    public wrap: DetachedMarkerSignalWrapCommon<TQ>;
    public signal_in_finally: boolean;
    
    public procedure Init(q: TQ; wrap: DetachedMarkerSignalWrapCommon<TQ>; signal_in_finally: boolean);
    begin
      self.q := q;
      self.wrap := wrap;
      self.signal_in_finally := signal_in_finally;
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>) := q.InitBeforeInvoke(g, inited_hubs);
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(prev_qr: TR; err_handler: CLTaskErrHandler): TR; where TR: IQueueRes;
    begin
      if prev_qr.ShouldInstaCallAction then
        wrap.SendSignal else
      if signal_in_finally then
        prev_qr.AddAction(c->wrap.SendSignal()) else
        prev_qr.AddAction(c->if not err_handler.HadError(true) then wrap.SendSignal);
      Result := prev_qr;
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>);
    begin
      sb += #10;
      
      sb.Append(#9, tabs);
      wrap.ToStringHeader(sb, index);
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  DetachedMarkerSignalWrapperNil = sealed class(DetachedMarkerSignalWrapCommon<CommandQueueNil>)
    
  end;
  DetachedMarkerSignalNil = sealed partial class(CommandQueueNil)
    data: DetachedMarkerSignalCommon<CommandQueueNil>;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := data.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := data.Invoke(data.q.InvokeToNil(g,l), g.curr_err_handler);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    data.ToString(sb, tabs, index, delayed);
    
  end;
  
  DetachedMarkerSignalWrapper<T> = sealed class(DetachedMarkerSignalWrapCommon<CommandQueue<T>>)
    
  end;
  DetachedMarkerSignal<T> = sealed partial class(CommandQueue<T>)
    data: DetachedMarkerSignalCommon<CommandQueue<T>>;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := data.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := data.Invoke(data.q.InvokeToNil(g,l), g.curr_err_handler);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := data.Invoke(data.q.InvokeToVal(g,l), g.curr_err_handler);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := data.Invoke(data.q.InvokeToPtr(g,l), g.curr_err_handler);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    data.ToString(sb, tabs, index, delayed);
    
  end;
  
function DetachedMarkerSignalNil.get_signal_in_finally := data.signal_in_finally;
function DetachedMarkerSignal<T>.get_signal_in_finally := data.signal_in_finally;

constructor DetachedMarkerSignalNil.Create(q: CommandQueueNil; signal_in_finally: boolean) :=
data.Init(q, new DetachedMarkerSignalWrapperNil(self), signal_in_finally);
constructor DetachedMarkerSignal<T>.Create(q: CommandQueue<T>; signal_in_finally: boolean) :=
data.Init(q, new DetachedMarkerSignalWrapper<T>(self), signal_in_finally);

static function DetachedMarkerSignalNil.operator implicit(dms: DetachedMarkerSignalNil) := dms.data.wrap;
static function DetachedMarkerSignal<T>.operator implicit(dms: DetachedMarkerSignal<T>) := dms.data.wrap;

{$endregion ThenMarkerSignal}

{$region WaitFor}

type
  CommandQueueWaitFor = sealed class(CommandQueueNil)
    public marker: WaitMarker;
    public constructor(marker: WaitMarker) := self.marker := marker;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    marker.InitInnerHandles(g);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override :=
    new QueueResNil(new CLTaskLocalData( marker.MakeWaitEv(g,l) ));
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      marker.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
function WaitFor(marker: WaitMarker) := new CommandQueueWaitFor(marker);

{$endregion WaitFor}

{$region ThenWaitFor}

type
  CommandQueueThenBaseWaitFor<T> = abstract class(CommandQueue<T>)
    public q: CommandQueue<T>;
    public marker: WaitMarker;
    
    public constructor(q: CommandQueue<T>; marker: WaitMarker);
    begin
      self.q := q;
      self.marker := marker;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override;
    begin
      q.InitBeforeInvoke(g, inited_hubs);
      marker.InitInnerHandles(g);
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
      marker.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  CommandQueueThenWaitFor<T> = sealed class(CommandQueueThenBaseWaitFor<T>)
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var res_ev := marker.MakeWaitEv(g, q.InvokeToNil(g, l).base );
      Result := new QueueResNil(new CLTaskLocalData(res_ev));
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(prev_qr: QueueRes<T>; g: CLTaskGlobalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      var res_ev := marker.MakeWaitEv(g, prev_qr.AttachInvokeActions(g));
      Result := prev_qr.WrapResult(qr_factory, res_ev);
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(q.InvokeToAny(g,l), g, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(q.InvokeToAny(g,l), g, qr_ptr_factory);
    
  end;
  CommandQueueThenFinallyWaitFor<T> = sealed class(CommandQueueThenBaseWaitFor<T>)
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; invoke_q: CommandQueueInvoker<TR>): ValueTuple<TR, EventList>; where TR: IQueueRes;
    begin
      
      var pre_q_err_handler := g.curr_err_handler;
      var prev_qr := invoke_q(g, l);
      var post_q_err_handler := g.curr_err_handler;
      
      g.curr_err_handler := pre_q_err_handler;
      var res_ev := marker.MakeWaitEv(g, prev_qr.AttachInvokeActions(g));
      {$ifdef DEBUG}
      if g.curr_err_handler <> pre_q_err_handler then
        raise new OpenCLABCInternalException($'MakeWaitEv should not change g.curr_err_handler');
      // Otherwise, CLTaskErrHandlerBranchBase (like in >=) would be needed
      {$endif DEBUG}
      g.curr_err_handler := post_q_err_handler;
      
      Result := ValueTuple.Create(prev_qr, res_ev);
    end;
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      var (prev_qr, ev) := Invoke(g, l, q.InvokeToAny);
      Result := prev_qr.WrapResult(qr_factory, ev);
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var (prev_qr, ev) := Invoke(g, l, q.InvokeToNil);
      Result := new QueueResNil(new CLTaskLocalData(ev));
    end;
    
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(g, l, qr_ptr_factory);
    
  end;
  
function CommandQueue<T>.ThenWaitFor(marker: WaitMarker) := new CommandQueueThenWaitFor<T>(self, marker);
function CommandQueue<T>.ThenFinallyWaitFor(marker: WaitMarker) := new CommandQueueThenFinallyWaitFor<T>(self, marker);

{$endregion ThenWaitFor}

{$endregion Wait}

{$region Finally}

type
  CommandQueueTryFinallyCommon<TQ> = record
  where TQ: CommandQueueBase;
    public try_do: CommandQueueBase;
    public do_finally: TQ;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>);
    begin
      try_do.InitBeforeInvoke(g, inited_hubs);
      do_finally.InitBeforeInvoke(g, inited_hubs);
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; invoke_finally: CommandQueueInvoker<TR>): TR; where TR: IQueueRes;
    begin
      var origin_err_handler := g.curr_err_handler;
      
      {$region try_do}
      
      g.curr_err_handler := new CLTaskErrHandlerBranchBase(origin_err_handler);
      l := try_do.InvokeToNil(g, l).base;
      var try_handler := g.curr_err_handler;
      
      {$endregion try_do}
      
      {$region do_finally}
      
      g.curr_err_handler := new CLTaskErrHandlerBranchBase(origin_err_handler);
      Result := invoke_finally(g, l);
      var fin_handler := g.curr_err_handler;
      
      {$endregion do_finally}
      
      g.curr_err_handler := new CLTaskErrHandlerBranchCombinator(origin_err_handler, |try_handler, fin_handler|);
    end;
    
    public [MethodImpl(MethodImplOptions.AggressiveInlining)]
    procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>);
    begin
      sb += #10;
      try_do.ToString(sb, tabs, index, delayed);
      do_finally.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  CommandQueueTryFinallyNil = sealed class(CommandQueueNil)
    private data := new CommandQueueTryFinallyCommon< CommandQueueNil >;
    
    private constructor(try_do: CommandQueueBase; do_finally: CommandQueueNil);
    begin
      data.try_do := try_do;
      data.do_finally := do_finally;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    data.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := data.Invoke(g, l, data.do_finally.InvokeToNil);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    data.ToString(sb, tabs, index, delayed);
    
  end;
  CommandQueueTryFinally<T> = sealed class(CommandQueue<T>)
    private data := new CommandQueueTryFinallyCommon< CommandQueue<T> >;
    
    private constructor(try_do: CommandQueueBase; do_finally: CommandQueue<T>);
    begin
      data.try_do := try_do;
      data.do_finally := do_finally;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    data.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;    override := data.Invoke(g, l, data.do_finally.InvokeToNil);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := data.Invoke(g, l, data.do_finally.InvokeToVal);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := data.Invoke(g, l, data.do_finally.InvokeToPtr);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    data.ToString(sb, tabs, index, delayed);
    
  end;
  
static function CommandQueueNil.operator>=(try_do: CommandQueueBase; do_finally: CommandQueueNil) :=
new CommandQueueTryFinallyNil(try_do, do_finally);
static function CommandQueue<T>.operator>=(try_do: CommandQueueBase; do_finally: CommandQueue<T>) :=
new CommandQueueTryFinally<T>(try_do, do_finally);

{$endregion Finally}

{$region Handle}

type
  
  CommandQueueHandleWithoutRes = sealed class(CommandQueueNil)
    private try_do: CommandQueueBase;
    private handler: Exception->boolean;
    
    public constructor(try_do: CommandQueueBase; handler: Exception->boolean);
    begin
      self.try_do := try_do;
      self.handler := handler;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    try_do.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      Result := try_do.InvokeToNil(g, l);
      var err_handler := g.curr_err_handler;
      // For current handler to not consume future errors
      g.curr_err_handler := new CLTaskErrHandlerSimpleRepeater(err_handler);
      Result.AddAction(c->
      try
        err_handler.TryRemoveErrors(self.handler);
      except
        on e: Exception do err_handler.AddErr(e);
      end);
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      try_do.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, handler);
      sb += #10;
      
    end;
    
  end;
  
  CommandQueueHandleDefaultRes<T> = sealed class(CommandQueue<T>)
    private q: CommandQueue<T>;
    private handler: Exception->boolean;
    private def: T;
    
    public constructor(q: CommandQueue<T>; handler: Exception->boolean; def: T);
    begin
      self.q := q;
      self.handler := handler;
      self.def := def;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      Result := q.InvokeToNil(g, l);
      var err_handler := g.curr_err_handler;
      g.curr_err_handler := new CLTaskErrHandlerSimpleRepeater(err_handler);
      Result.AddAction(c->
      try
        err_handler.TryRemoveErrors(self.handler);
      except
        on e: Exception do err_handler.AddErr(e);
      end);
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(prev_qr: QueueRes<T>; g: CLTaskGlobalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      var err_handler := g.curr_err_handler;
      g.curr_err_handler := new CLTaskErrHandlerSimpleRepeater(err_handler);
      
      Result := prev_qr.TransformResult(qr_factory, g.c, true, (prev_res,c)->
      if not err_handler.HadError(true) then
        Result := prev_res else
      try
        err_handler.TryRemoveErrors(self.handler);
        Result := self.def;
      except
        on e: Exception do err_handler.AddErr(e);
      end);
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(q.InvokeToAny(g,l), g, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(q.InvokeToAny(g,l), g, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringRuntimeValue(sb, self.def);
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, handler);
      sb += #10;
      
    end;
    
  end;
  
  CommandQueueHandleReplaceRes<T> = sealed class(CommandQueue<T>)
    private q: CommandQueue<T>;
    private handler: List<Exception> -> T;
    
    public constructor(q: CommandQueue<T>; handler: List<Exception> -> T);
    begin
      self.q := q;
      self.handler := handler;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      Result := q.InvokeToNil(g, l);
      var err_handler := new CLTaskErrHandlerThief(g.curr_err_handler);
      g.curr_err_handler := new CLTaskErrHandlerSimpleRepeater(err_handler);
      Result.AddAction(c->
      if err_handler.HadError(true) then
      begin
        err_handler.StealPrevErrors;
        try
          self.handler(err_handler.get_local_err_lst);
        except
          on e: Exception do err_handler.AddErr(e);
        end;
      end);
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(prev_qr: QueueRes<T>; g: CLTaskGlobalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      var err_handler := new CLTaskErrHandlerThief(g.curr_err_handler);
      g.curr_err_handler := new CLTaskErrHandlerSimpleRepeater(err_handler);
      
      Result := prev_qr.TransformResult(qr_factory, g.c, true, (prev_res,c)->
      if not err_handler.HadError(true) then
        Result := prev_res else
      begin
        err_handler.StealPrevErrors;
        try
          Result := self.handler(err_handler.get_local_err_lst);
        except
          on e: Exception do err_handler.AddErr(e);
        end;
      end);
      
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(q.InvokeToAny(g,l), g, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(q.InvokeToAny(g,l), g, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      
      q.ToString(sb, tabs, index, delayed);
      
      sb.Append(#9, tabs);
      ToStringWriteDelegate(sb, handler);
      sb += #10;
      
    end;
    
  end;
  
function CommandQueueBase.HandleWithoutRes(handler: Exception->boolean) :=
new CommandQueueHandleWithoutRes(self, handler);

function CommandQueue<T>.HandleDefaultRes(handler: Exception->boolean; def: T): CommandQueue<T> :=
new CommandQueueHandleDefaultRes<T>(self, handler, def);

function CommandQueue<T>.HandleReplaceRes(handler: List<Exception> -> T) :=
new CommandQueueHandleReplaceRes<T>(self, handler);

{$endregion Handle}

{$endregion Queue converter's}

{$region KernelArg}

{$region Base}

type
  ISetableKernelArg = interface
    procedure SetArg(k: cl_kernel; ind: UInt32);
  end;
  KernelArg = abstract partial class
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; abstract;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); abstract;
    
  end;
  
{$endregion Base}

{$region Const}

{$region Base}

type
  ConstKernelArg = abstract class(KernelArg, ISetableKernelArg)
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override :=
    new QueueResVal<ISetableKernelArg>(new CLTaskLocalData, self);
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); abstract;
    
  end;
  
{$endregion Base}

{$region CLArray}

type
  KernelArgCLArray<T> = sealed class(ConstKernelArg)
  where T: record;
    private a: CLArray<T>;
    
    public constructor(a: CLArray<T>) := self.a := a;
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
    OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, new UIntPtr(cl_mem.Size), a.ntv) );
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringRuntimeValue(sb, self.a);
      sb += #10;
    end;
    
  end;
  
static function KernelArg.FromCLArray<T>(a: CLArray<T>): KernelArg; where T: record;
begin Result := new KernelArgCLArray<T>(a); end;

{$endregion CLArray}

{$region MemorySegment}

type
  KernelArgMemorySegment = sealed class(ConstKernelArg)
    private mem: MemorySegment;
    
    public constructor(mem: MemorySegment) := self.mem := mem;
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
   OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, new UIntPtr(cl_mem.Size), mem.ntv) );
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringRuntimeValue(sb, self.mem);
      sb += #10;
    end;
    
  end;
  
static function KernelArg.FromMemorySegment(mem: MemorySegment) := new KernelArgMemorySegment(mem);

{$endregion MemorySegment}

{$region Ptr}

type
  KernelArgData = sealed class(ConstKernelArg)
    private ptr: IntPtr;
    private sz: UIntPtr;
    
    public constructor(ptr: IntPtr; sz: UIntPtr);
    begin
      self.ptr := ptr;
      self.sz := sz;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
    OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, sz, pointer(ptr)) );
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ' => ';
      sb.Append(ptr);
      sb += '[';
      sb.Append(sz);
      sb += ']'#10;
    end;
    
  end;
  
static function KernelArg.FromData(ptr: IntPtr; sz: UIntPtr) := new KernelArgData(ptr, sz);

static function KernelArg.FromValueData<TRecord>(ptr: ^TRecord): KernelArg;
begin
  BlittableHelper.RaiseIfBad(typeof(TRecord), '%Err:Blittable:Source:KernelArg%');
  Result := KernelArg.FromData(new IntPtr(ptr), new UIntPtr(Marshal.SizeOf&<TRecord>));
end;

{$endregion Ptr}

{$region Value}

type
  KernelArgValue<TRecord> = sealed class(ConstKernelArg)
  where TRecord: record;
    private val: ^TRecord := pointer(Marshal.AllocHGlobal(Marshal.SizeOf&<TRecord>));
    
    static constructor :=
    BlittableHelper.RaiseIfBad(typeof(TRecord), '%Err:Blittable:Source:KernelArg%');
    
    public constructor(val: TRecord) := self.val^ := val;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure Finalize; override :=
    Marshal.FreeHGlobal(new IntPtr(val));
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
    OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, new UIntPtr(Marshal.SizeOf&<TRecord>), pointer(self.val)) ); 
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringRuntimeValue(sb, self.val^);
      sb += #10;
    end;
    
  end;
  
static function KernelArg.FromValue<TRecord>(val: TRecord) := new KernelArgValue<TRecord>(val);

{$endregion Value}

{$region NativeValue}

type
  KernelArgNativeValue<TRecord> = sealed class(ConstKernelArg)
  where TRecord: record;
    private val: NativeValue<TRecord>;
    
    public constructor(val: NativeValue<TRecord>) := self.val := val;
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
    OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, new UIntPtr(Marshal.SizeOf&<TRecord>), self.val.Pointer) ); 
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ' => ';
      sb += val.ToString;
      sb += #10;
    end;
    
  end;
  
static function KernelArg.FromNativeValue<TRecord>(val: NativeValue<TRecord>): KernelArg; where TRecord: record;
begin
  Result := new KernelArgNativeValue<TRecord>(val);
end;

{$endregion NativeValue}

{$region Array}

type
  KernelArgArray<TRecord> = sealed class(ConstKernelArg)
  where TRecord: record;
    private hnd: GCHandle;
    private offset: integer;
    private sz: UIntPtr;
    
    static constructor :=
    BlittableHelper.RaiseIfBad(typeof(TRecord), '%Err:Blittable:Source:KernelArg%');
    
    public constructor(a: array of TRecord; ind: integer);
    begin
      self.hnd := GCHandle.Alloc(a, GCHandleType.Pinned);
      self.offset := Marshal.SizeOf&<TRecord> * ind;
      self.sz := new UIntPtr(Marshal.SizeOf&<TRecord> * (a.Length-ind));
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure Finalize; override :=
    if hnd.IsAllocated then hnd.Free;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
    OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, sz, (hnd.AddrOfPinnedObject+offset).ToPointer) ); 
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringRuntimeValue(sb, hnd.Target as array of TRecord);
      if offset<>0 then
      begin
        sb += '+';
        sb.Append(offset);
        sb += 'b';
      end;
      sb += #10;
    end;
    
  end;
  
static function KernelArg.FromArray<TRecord>(a: array of TRecord; ind: integer) := new KernelArgArray<TRecord>(a, ind);

{$endregion Array}

{$endregion Const}

{$region Invokeable}

{$region Base}

type
  InvokeableKernelArg = abstract class(KernelArg)
    protected static kqr_factory := new QueueResValFactory<ISetableKernelArg>;
  end;
  
{$endregion Base}

{$region CLArray}

type
  KernelArgCLArrayCQ<T> = sealed class(InvokeableKernelArg)
  where T: record;
    public q: CommandQueue<CLArray<T>>;
    public constructor(q: CommandQueue<CLArray<T>>) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override :=
    q.InvokeToAny(g, l).TransformResult(kqr_factory, g.c, true, (a,c)->new KernelArgCLArray<T>(a) as ISetableKernelArg);
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function KernelArg.FromCLArrayCQ<T>(a_q: CommandQueue<CLArray<T>>): KernelArg; where T: record;
begin Result := new KernelArgCLArrayCQ<T>(a_q); end;

{$endregion CLArray}

{$region MemorySegment}

type
  KernelArgMemorySegmentCQ = sealed class(InvokeableKernelArg)
    public q: CommandQueue<MemorySegment>;
    public constructor(q: CommandQueue<MemorySegment>) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override :=
    q.InvokeToAny(g, l).TransformResult(kqr_factory, g.c, true, (mem,c)->new KernelArgMemorySegment(mem) as ISetableKernelArg);
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function KernelArg.FromMemorySegmentCQ(mem_q: CommandQueue<MemorySegment>) :=
new KernelArgMemorySegmentCQ(mem_q);

{$endregion MemorySegment}

{$region Ptr}

type
  KernelArgDataCQ = sealed class(InvokeableKernelArg)
    public ptr_q: CommandQueue<IntPtr>;
    public sz_q: CommandQueue<UIntPtr>;
    public constructor(ptr_q: CommandQueue<IntPtr>; sz_q: CommandQueue<UIntPtr>);
    begin
      self.ptr_q := ptr_q;
      self.sz_q := sz_q;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override;
    begin
      var ptr_qr: QueueRes<IntPtr>;
      var  sz_qr: QueueRes<UIntPtr>;
      // as_new=false, because KernelArg should be invoked as new (independant of prev errors and events)
      g.ParallelInvoke(l, false, 2, invoker->
      begin
        ptr_qr := invoker.InvokeBranch(ptr_q.InvokeToAny);
         sz_qr := invoker.InvokeBranch( sz_q.InvokeToAny);
      end);
      var res_ev := ptr_qr.AttachInvokeActions(g) + sz_qr.AttachInvokeActions(g);
      var res_l := new CLTaskLocalData(res_ev);
      if ptr_qr.IsConst and sz_qr.IsConst then
        Result := new QueueResVal<ISetableKernelArg>(res_l, new KernelArgData(ptr_qr.GetResDirect, sz_qr.GetResDirect)) else
      begin
        Result := new QueueResVal<ISetableKernelArg>(res_l);
        Result.AddResSetter(c->new KernelArgData(ptr_qr.GetResDirect, sz_qr.GetResDirect));
      end;
    end;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override;
    begin
      ptr_q.InitBeforeInvoke(g, inited_hubs);
       sz_q.InitBeforeInvoke(g, inited_hubs);
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      ptr_q.ToString(sb, tabs, index, delayed);
       sz_q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function KernelArg.FromDataCQ(ptr_q: CommandQueue<IntPtr>; sz_q: CommandQueue<UIntPtr>) :=
new KernelArgDataCQ(ptr_q, sz_q);

{$endregion Ptr}

{$region Value}

type
  KernelArgPtrQr<TRecord> = sealed class(ConstKernelArg)
    public qr: QueueResPtr<TRecord>;
    
    public constructor(qr: QueueResPtr<TRecord>) := self.qr := qr;
    private constructor := raise new OpenCLABCInternalException;
    
    public procedure SetArg(k: cl_kernel; ind: UInt32); override :=
    OpenCLABCInternalException.RaiseIfError( cl.SetKernelArg(k, ind, new UIntPtr(Marshal.SizeOf&<TRecord>), qr.res) );
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override :=
    raise new System.NotSupportedException;
    
  end;
  
  KernelArgValueCQ<TRecord> = sealed class(InvokeableKernelArg)
  where TRecord: record;
    public q: CommandQueue<TRecord>;
    
    static constructor :=
    BlittableHelper.RaiseIfBad(typeof(TRecord), '%Err:Blittable:Source:KernelArg%');
    
    public constructor(q: CommandQueue<TRecord>) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override;
    begin
      var prev_qr := q.InvokeToPtr(g, l);
      Result := new QueueResVal<ISetableKernelArg>(
        new CLTaskLocalData(prev_qr.ResEv),
        new KernelArgPtrQr<TRecord>(prev_qr)
      );
      prev_qr.TransplantActionsTo(Result);
    end;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function KernelArg.FromValueCQ<TRecord>(valq: CommandQueue<TRecord>) :=
new KernelArgValueCQ<TRecord>(valq);

{$endregion Value}

{$region NativeValue}

type
  KernelArgNativeValueCQ<TRecord> = sealed class(InvokeableKernelArg)
  where TRecord: record;
    public q: CommandQueue<NativeValue<TRecord>>;
    
    public constructor(q: CommandQueue<NativeValue<TRecord>>) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override :=
    q.InvokeToAny(g, l).TransformResult(kqr_factory, g.c, true, (nv,c)->new KernelArgNativeValue<TRecord>(nv) as ISetableKernelArg);
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function KernelArg.FromNativeValueCQ<TRecord>(valq: CommandQueue<NativeValue<TRecord>>): KernelArg; where TRecord: record;
begin
  Result := new KernelArgNativeValueCQ<TRecord>(valq);
end;

{$endregion NativeValue}

{$region Array}

type
  KernelArgArrayCQ<TRecord> = sealed class(InvokeableKernelArg)
  where TRecord: record;
    public a_q: CommandQueue<array of TRecord>;
    public ind_q: CommandQueue<integer>;
    
    static constructor :=
    BlittableHelper.RaiseIfBad(typeof(TRecord), '%Err:Blittable:Source:KernelArg%');
    
    public constructor(a_q: CommandQueue<array of TRecord>; ind_q: CommandQueue<integer>);
    begin
      self.  a_q :=   a_q;
      self.ind_q := ind_q;
    end;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<ISetableKernelArg>; override;
    begin
      var   a_qr: QueueRes<array of TRecord>;
      var ind_qr: QueueRes<integer>;
      g.ParallelInvoke(l, false, 2, invoker->
      begin
          a_qr := invoker.InvokeBranch(  a_q.InvokeToAny);
        ind_qr := invoker.InvokeBranch(ind_q.InvokeToAny);
      end);
      var res_ev := a_qr.AttachInvokeActions(g) + ind_qr.AttachInvokeActions(g);
      var res_l := new CLTaskLocalData(res_ev);
      if a_qr.IsConst and ind_qr.IsConst then
        Result := new QueueResVal<ISetableKernelArg>(res_l, new KernelArgArray<TRecord>(a_qr.GetResDirect, ind_qr.GetResDirect)) else
      begin
        Result := new QueueResVal<ISetableKernelArg>(res_l);
        Result.AddResSetter(c->new KernelArgArray<TRecord>(a_qr.GetResDirect, ind_qr.GetResDirect));
      end;
    end;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override;
    begin
        a_q.InitBeforeInvoke(g, inited_hubs);
      ind_q.InitBeforeInvoke(g, inited_hubs);
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
        a_q.ToString(sb, tabs, index, delayed);
      ind_q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function KernelArg.FromArrayCQ<TRecord>(a_q: CommandQueue<array of TRecord>; ind_q: CommandQueue<integer>) :=
new KernelArgArrayCQ<TRecord>(a_q, ind_q);

{$endregion Array}

{$endregion Invokeable}

{$endregion KernelArg}

{$region GPUCommand}

{$region Base}

type
  GPUCommandObjInvoker<T> = CommandQueueInvoker<QueueResVal<T>>;
  
  GPUCommand<T> = abstract class
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); abstract;
    
    protected function InvokeObj  (o: T;                              g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; abstract;
    protected function InvokeQueue(o_invoke: GPUCommandObjInvoker<T>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; abstract;
    
    protected function DisplayName: string; virtual := CommandQueueBase.DisplayNameForType(self.GetType);
    protected static procedure ToStringWriteDelegate(sb: StringBuilder; d: System.Delegate) := CommandQueueBase.ToStringWriteDelegate(sb,d);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); abstract;
    
    private procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>);
    begin
      sb.Append(#9, tabs);
      sb += DisplayName;
      self.ToStringImpl(sb, tabs+1, index, delayed);
    end;
    
  end;
  
  BasicGPUCommand<T> = abstract class(GPUCommand<T>)
    
    protected function DisplayName: string; override;
    begin
      Result := self.GetType.Name;
      Result := Result.Remove(Result.IndexOf('`'));
    end;
    
    public static function MakeQueue(q: CommandQueueBase): BasicGPUCommand<T>;
    
    public static function MakeBackgroundProc(p: T->()): BasicGPUCommand<T>;
    public static function MakeBackgroundProc(p: (T,Context)->()): BasicGPUCommand<T>;
    public static function MakeQuickProc(p: T->()): BasicGPUCommand<T>;
    public static function MakeQuickProc(p: (T,Context)->()): BasicGPUCommand<T>;
    
    public static function MakeWait(m: WaitMarker): BasicGPUCommand<T>;
    
  end;
  
{$endregion Base}

{$region Queue}

type
  QueueCommand<T> = sealed class(BasicGPUCommand<T>)
    public q: CommandQueueBase;
    
    public constructor(q: CommandQueueBase) := self.q := q;
    private constructor := raise new OpenCLABCInternalException;
    
    protected function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData) := q.InvokeToNil(g, l);
    
    protected function InvokeObj  (o: T;                              g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := Invoke(g, l);
    protected function InvokeQueue(o_invoke: GPUCommandObjInvoker<T>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := Invoke(g, l);
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    q.InitBeforeInvoke(g, inited_hubs);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  QueueCommandFactory<TObj> = sealed class(ITypedCQConverter<BasicGPUCommand<TObj>>)
    
    public function ConvertNil(cq: CommandQueueNil): BasicGPUCommand<TObj> := new QueueCommand<TObj>(cq);
    public function Convert<T>(cq: CommandQueue<T>): BasicGPUCommand<TObj> :=
    if cq is ConstQueue<T> then nil else
    if cq is ParameterQueue<T> then nil else
    if cq is CastQueueBase<T>(var ccq) then
      ccq.SourceBase.ConvertTyped(self) else
      new QueueCommand<TObj>(cq);
    
  end;
  
static function BasicGPUCommand<T>.MakeQueue(q: CommandQueueBase) := q.ConvertTyped(new QueueCommandFactory<T>);

{$endregion Queue}

{$region Proc}

{$region Base}

type
  ProcCommandBase<T, TProc> = abstract class(BasicGPUCommand<T>)
  where TProc: Delegate;
    public p: TProc;
    
    public constructor(p: TProc) := self.p := p;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure ExecProc(o: T; c: Context); abstract;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      ToStringWriteDelegate(sb, p);
      sb += #10;
    end;
    
  end;
  
{$endregion Base}

type
  BackgroundProcCommandBase<T, TProc> = abstract class(ProcCommandBase<T, TProc>)
  where TProc: Delegate;
    
    protected function InvokeObj(o: T; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var prev_d := l.prev_delegate;
      var c := g.c;
      var err_handler := g.curr_err_handler;
      new QueueResNil(new CLTaskLocalData(
        UserEvent.StartBackgroundWork(l.prev_ev,
          ()->
          begin
            prev_d.Invoke(c);
            try
              ExecProc(o, c);
            except
              on e: Exception do err_handler.AddErr(e);
            end;
          end,
          g.cl_c{$ifdef EventDebug}, $'const body of {self.GetType}'{$endif}
        )
      ));
    end;
    
    protected function InvokeQueue(o_invoke: GPUCommandObjInvoker<T>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var o_qr := o_invoke(g, l);
      var c := g.c;
      var err_handler := g.curr_err_handler;
      Result := new QueueResNil(new CLTaskLocalData(
        UserEvent.StartBackgroundWork(o_qr.ResEv,
          ()->
          begin
            var o := o_qr.GetRes(c);
            try
              ExecProc(o, c);
            except
              on e: Exception do err_handler.AddErr(e);
            end;
          end,
          g.cl_c{$ifdef EventDebug}, $'queue body of {self.GetType}'{$endif}
        )
      ));
    end;
    
  end;
  
  BackgroundProcCommand<T> = sealed class(BackgroundProcCommandBase<T, T->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o);
    
  end;
  BackgroundProcCommandC<T> = sealed class(BackgroundProcCommandBase<T, (T,Context)->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o, c);
    
  end;
  
static function BasicGPUCommand<T>.MakeBackgroundProc(p: T->()) := new BackgroundProcCommand<T>(p);
static function BasicGPUCommand<T>.MakeBackgroundProc(p: (T,Context)->()) := new BackgroundProcCommandC<T>(p);

type
  QuickProcCommandBase<T, TProc> = abstract class(ProcCommandBase<T, TProc>)
  where TProc: Delegate;
    
    private function Invoke(prev_qr: QueueRes<T>; g: CLTaskGlobalData): QueueResNil;
    begin
      Result := new QueueResNil(prev_qr.base);
      
      var d := QueueResActionUtils.HandlerWrap(g.curr_err_handler, ExecProc);
      if prev_qr.ShouldInstaCallAction then
        d(prev_qr.GetResDirect, g.c) else
        Result.AddAction(c->d(prev_qr.GetResDirect, c));
      
      prev_qr.TransplantActionsNowhere;
    end;
    
    protected function InvokeObj  (o: T;                              g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := Invoke(new QueueResVal<T>(l, o), g);
    protected function InvokeQueue(o_invoke: GPUCommandObjInvoker<T>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := Invoke(o_invoke(g, l), g);
    
  end;
  
  QuickProcCommand<T> = sealed class(QuickProcCommandBase<T, T->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o);
    
  end;
  QuickProcCommandC<T> = sealed class(QuickProcCommandBase<T, (T,Context)->()>)
    
    protected procedure ExecProc(o: T; c: Context); override := p(o, c);
    
  end;
  
static function BasicGPUCommand<T>.MakeQuickProc(p: T->()) := new QuickProcCommand<T>(p);
static function BasicGPUCommand<T>.MakeQuickProc(p: (T,Context)->()) := new QuickProcCommandC<T>(p);

{$endregion Proc}

{$region Wait}

type
  WaitCommand<T> = sealed class(BasicGPUCommand<T>)
    public marker: WaitMarker;
    
    public constructor(marker: WaitMarker) := self.marker := marker;
    private constructor := raise new OpenCLABCInternalException;
    
    private function Invoke(g: CLTaskGlobalData; l: CLTaskLocalData) :=
    new QueueResNil(new CLTaskLocalData( marker.MakeWaitEv(g,l) ));
    
    protected function InvokeObj  (o: T;                              g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := Invoke(g, l);
    protected function InvokeQueue(o_invoke: GPUCommandObjInvoker<T>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := Invoke(g, l);
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    marker.InitInnerHandles(g);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      marker.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
static function BasicGPUCommand<T>.MakeWait(m: WaitMarker) := new WaitCommand<T>(m);

{$endregion Wait}

{$endregion GPUCommand}

{$region GPUCommandContainer}

{$region Base}

type
  GPUCommandContainer<T> = abstract partial class
    private constructor := raise new OpenCLABCInternalException;
  end;
  GPUCommandContainerCore<T> = abstract class
    private cc: GPUCommandContainer<T>;
    protected constructor(cc: GPUCommandContainer<T>) := self.cc := cc;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); abstract;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; abstract;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; abstract;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); abstract;
    private procedure ToString(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>);
    begin
      sb.Append(#9, tabs);
      
      var tn := self.GetType.Name;
      sb += tn.Remove(tn.IndexOf('`'));
      
      self.ToStringImpl(sb, tabs+1, index, delayed);
    end;
    
  end;
  
  GPUCommandContainer<T> = abstract partial class(CommandQueue<T>)
    protected core: GPUCommandContainerCore<T>;
    protected commands := new List<GPUCommand<T>>;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override;
    begin
      core.InitBeforeInvoke(g, inited_hubs);
      foreach var comm in commands do comm.InitBeforeInvoke(g, inited_hubs);
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override    := core.InvokeToNil(g, l);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := core.InvokeToVal(g, l);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override;
    begin
      Result := nil;
      raise new OpenCLABCInternalException($'Err:Invoke:InvalidToPtr');
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      core.ToString(sb, tabs, index, delayed);
      foreach var comm in commands do
        comm.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
function AddCommand<TContainer, TRes>(cc: TContainer; comm: GPUCommand<TRes>): TContainer; where TContainer: GPUCommandContainer<TRes>;
begin
  cc.commands += comm;
  Result := cc;
end;

{$endregion Base}

{$region Core}

type
  CCCObj<T> = sealed class(GPUCommandContainerCore<T>)
    public o: T;
    
    public constructor(cc: GPUCommandContainer<T>; o: T);
    begin
      inherited Create(cc);
      self.o := o;
    end;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; make_qr: (CLTaskLocalData, T)->TR): TR;
    begin
      var o := self.o;
      
      foreach var comm in cc.commands do
        l := comm.InvokeObj(o, g, l).base;
      
      Result := make_qr(l, o);
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override    := Invoke(g, l, (l,o)->new QueueResNil(l));
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, (l,o)->new QueueResVal<T>(l,o));
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += ': ';
      CommandQueueBase.ToStringRuntimeValue(sb, self.o);
      sb += #10;
    end;
    
  end;
  
  CCCQueue<T> = sealed class(GPUCommandContainerCore<T>)
    public hub: MultiusableCommandQueueHub<T>;
    
    public constructor(cc: GPUCommandContainer<T>; q: CommandQueue<T>);
    begin
      inherited Create(cc);
      self.hub := new MultiusableCommandQueueHub<T>(q);
    end;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override :=
    hub.q.InitBeforeInvoke(g, inited_hubs);
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; make_qr: (GPUCommandObjInvoker<T>,CLTaskGlobalData,CLTaskLocalData)->TR): TR;
    begin
      var invoke_plug: GPUCommandObjInvoker<T> := hub.MakeNode.InvokeToVal;
      
      foreach var comm in cc.commands do
        l := comm.InvokeQueue(invoke_plug, g, l).base;
      
      Result := make_qr(invoke_plug, g, l);
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;    override := Invoke(g, l, (inv,g,l)->new QueueResNil(l));
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, (inv,g,l)->inv(g,l));
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override;
    begin
      sb += #10;
      hub.q.ToString(sb, tabs, index, delayed);
    end;
    
  end;
  
  GPUCommandContainer<T> = abstract partial class
    
    protected constructor(o: T) :=
    self.core := new CCCObj<T>(self, o);
    
    protected constructor(q: CommandQueue<T>) :=
    self.core := new CCCQueue<T>(self, q);
    
  end;
  
{$endregion Core}

{$region Kernel}

type
  KernelCCQ = sealed partial class(GPUCommandContainer<Kernel>)
    
  end;
  
{%ContainerCommon\Kernel\Implementation!ContainerCommon.pas%}

{$endregion Kernel}

{$region MemorySegment}

type
  MemorySegmentCCQ = sealed partial class(GPUCommandContainer<MemorySegment>)
    
  end;
  
static function KernelArg.operator implicit(mem_q: MemorySegmentCCQ): KernelArg := FromMemorySegmentCQ(mem_q);

{%ContainerCommon\MemorySegment\Implementation!ContainerCommon.pas%}

{$endregion MemorySegment}

{$region CLArray}

type
  CLArrayCCQ<T> = sealed partial class(GPUCommandContainer<CLArray<T>>)
    
  end;
  
static function KernelArg.operator implicit<T>(a_q: CLArrayCCQ<T>): KernelArg; where T: record;
//TODO #2550
begin Result := FromCLArrayCQ(a_q as object as GPUCommandContainer<CLArray<T>>); end;

{%ContainerCommon\CLArray\Implementation!ContainerCommon.pas%}

{$endregion CLArray}

{$endregion GPUCommandContainer}

{$region Enqueueable's}

{$region Core}

type
  EnqEvLst = sealed class
    private evs: array of EventList;
    private c1 := 0;
    private c2 := 0;
    {$ifdef DEBUG}
    private skipped := 0;
    {$endif DEBUG}
    
    public constructor(cap: integer) :=
    evs := new EventList[cap];
    private constructor := raise new OpenCLABCInternalException;
    
    public property Capacity: integer read evs.Length;
    
    public procedure AddL1(ev: EventList);
    begin
      {$ifdef DEBUG}
      if c1+c2+skipped = evs.Length then raise new OpenCLABCInternalException($'Not enough EnqEv capacity');
      {$endif DEBUG}
      if ev.count=0 then
        {$ifdef DEBUG}skipped += 1{$endif} else
      begin
        evs[c1] := ev;
        c1 += 1;
      end;
    end;
    public procedure AddL2(ev: EventList);
    begin
      {$ifdef DEBUG}
      if c1+c2+skipped = evs.Length then raise new OpenCLABCInternalException($'Not enough EnqEv capacity');
      {$endif DEBUG}
      if ev.count=0 then
        {$ifdef DEBUG}skipped += 1{$endif} else
      begin
        c2 += 1;
        evs[evs.Length-c2] := ev;
      end;
    end;
    
    private procedure CheckDone;
    begin
      {$ifdef DEBUG}
      if c1+c2+skipped <> evs.Length then raise new OpenCLABCInternalException($'Too much EnqEv capacity: {c1+c2+skipped}/{evs.Length} used');
      {$endif DEBUG}
    end;
    
    public function MakeLists: ValueTuple<EventList, EventList>;
    begin
      CheckDone;
      Result := ValueTuple.Create(
        EventList.Combine(new ArraySegment<EventList>(evs,0,c1)),
        EventList.Combine(new ArraySegment<EventList>(evs,evs.Length-c2,c2))
      );
    end;
    public function CombineAll: EventList;
    begin
      CheckDone;
      Result := EventList.Combine(evs);
    end;
    
  end;
  
  DirectEnqRes = ValueTuple<cl_event, QueueResAction>;
  EnqRes = ValueTuple<EventList, QueueResAction>;
  EnqueueableEnqFunc<TInvData> = function(inv_data: TInvData; c: Context; cq: cl_command_queue; ev_l2: EventList): DirectEnqRes;
  
  IEnqueueable<TInvData> = interface
    
    function EnqEvCapacity: integer;
    
    function InvokeParams(g: CLTaskGlobalData; enq_evs: EnqEvLst): EnqueueableEnqFunc<TInvData>;
    
  end;
  
  EnqueueableCore = static class
    
    private static function MakeEvList(exp_size: integer; start_ev: EventList): List<EventList>;
    begin
      var need_start_ev := start_ev.count<>0;
      Result := new List<EventList>(exp_size + integer(need_start_ev));
      if need_start_ev then Result += start_ev;
    end;
    
    private static function ExecuteEnqFunc<TInvData>(
      inv_data: TInvData; c: Context; cq: cl_command_queue; ev_l2: EventList;
      enq_f: EnqueueableEnqFunc<TInvData>; err_handler: CLTaskErrHandler
      {$ifdef EventDebug}; q: object{$endif}): EnqRes;
    begin
      Result := new EnqRes(ev_l2, nil);
      try
        var (enq_ev, act) := enq_f(inv_data, c, cq, ev_l2);
        {$ifdef EventDebug}
        EventDebug.RegisterEventRetain(enq_ev, $'Enq by {q.GetType}, waiting on [{ev_l2.evs?.JoinToString}]');
        {$endif EventDebug}
        // 1. ev_l2 can be released only after executing dependant command
        // 2. If event in ev_l2 would receive error, enq_ev would not give descriptive error
        Result := new EnqRes(ev_l2+enq_ev, act);
      except
        on e: Exception do err_handler.AddErr(e);
      end;
    end;
    
    public static function Invoke<TEnq, TInvData>(q: TEnq; inv_data: TInvData; g: CLTaskGlobalData; start_ev: EventList; start_ev_in_l1: boolean): EnqRes; where TEnq: IEnqueueable<TInvData>;
    begin
      var enq_evs := new EnqEvLst(q.EnqEvCapacity+1);
      if start_ev_in_l1 then
        enq_evs.AddL1(start_ev) else
        enq_evs.AddL2(start_ev);
      
      var pre_params_handler := g.curr_err_handler;
      if pre_params_handler.HadError(true) then
      begin
        Result := new EnqRes(enq_evs.CombineAll, nil);
        exit;
      end;
      
      var enq_f := q.InvokeParams(g, enq_evs);
      var (ev_l1, ev_l2) := enq_evs.MakeLists;
      var need_async_inv := ev_l1.count<>0;
      
      var post_params_handler := g.curr_err_handler;
      // When inv is async, post_params_handler
      // could be appened later, until ev_l2 is completed
      if post_params_handler.HadError(not need_async_inv) then
      begin
        Result := new EnqRes(ev_l2, nil);
        exit;
      end;
      
      // When inv is async, cq needs to be secured for thread safety
      // Otherwise, next command can be written before current one
      var cq := g.GetCQ(need_async_inv);
      {$ifdef QueueDebug}
      QueueDebug.Add(cq, q.GetType.ToString);
      {$endif QueueDebug}
      
      if not need_async_inv then
        Result := ExecuteEnqFunc(inv_data, g.c, cq, ev_l2, enq_f, post_params_handler{$ifdef EventDebug}, q{$endif}) else
      begin
        var res_ev := new UserEvent(g.cl_c
          {$ifdef EventDebug}, $'{q.GetType}, temp for nested AttachCallback: [{ev_l1.evs.JoinToString}], then [{ev_l2.evs?.JoinToString}]'{$endif}
        );
        
        ev_l1.MultiAttachCallback(()->
        begin
          var (enq_ev, enq_act) := ExecuteEnqFunc(inv_data, g.c, cq, ev_l2, enq_f, post_params_handler{$ifdef EventDebug}, q{$endif});
          enq_ev.MultiAttachCallback(()->
          begin
            if enq_act<>nil then enq_act(g.c);
            g.ReturnCQ(cq);
            res_ev.SetComplete;
          end{$ifdef EventDebug}, $'propagating Enq ev of {q.GetType} to res_ev: {res_ev.uev}'{$endif});
        end{$ifdef EventDebug}, $'calling async Enq of {q.GetType}'{$endif});
        
        Result := new EnqRes(res_ev, nil);
      end;
      
    end;
    
  end;
  
{$endregion Core}

{$region GPUCommand}

type
  EnqueueableGPUCommandInvData<T> = record
    qr: QueueRes<T>;
  end;
  EnqueueableGPUCommand<T> = abstract class(GPUCommand<T>, IEnqueueable<EnqueueableGPUCommandInvData<T>>)
    
    public function EnqEvCapacity: integer; abstract;
    
    protected function InvokeParamsImpl(g: CLTaskGlobalData; enq_evs: EnqEvLst): (T, cl_command_queue, EventList)->DirectEnqRes; abstract;
    public function InvokeParams(g: CLTaskGlobalData; enq_evs: EnqEvLst): EnqueueableEnqFunc<EnqueueableGPUCommandInvData<T>>;
    begin
      var enq_f := InvokeParamsImpl(g, enq_evs);
      Result := (data, c, lcq, ev)->enq_f(data.qr.GetRes(c), lcq, ev);
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke(g: CLTaskGlobalData; prev_qr: QueueRes<T>; start_ev: EventList; start_ev_in_l1: boolean): QueueResNil;
    begin
      var inv_data: EnqueueableGPUCommandInvData<T>;
      inv_data.qr  := prev_qr;
      
      var (enq_ev, enq_act) := EnqueueableCore.Invoke(self, inv_data, g, start_ev, start_ev_in_l1);
      var res := new QueueResNil(new CLTaskLocalData(enq_ev));
      if enq_act<>nil then res.AddAction(enq_act);
      
      Result := res;
    end;
    
    protected function InvokeObj(o: T; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override :=
    Invoke(g, new QueueResVal<T>(new CLTaskLocalData, o), l.prev_ev, false);
    
    protected function InvokeQueue(o_invoke: GPUCommandObjInvoker<T>; g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      var prev_qr := o_invoke(g, l);
      Result := Invoke(g, prev_qr, prev_qr.ResEv, not prev_qr.IsConst);
    end;
    
  end;
  
{$endregion GPUCommand}

{$region GetCommand}

type
  EnqueueableGetCommandInvData<TObj, TRes> = record
    prev_qr: QueueRes<TObj>;
    res_qr: QueueRes<TRes>;
  end;
  EnqueueableGetCommand<TObj, TRes> = abstract class(CommandQueue<TRes>, IEnqueueable<EnqueueableGetCommandInvData<TObj, TRes>>)
    protected prev_commands: GPUCommandContainer<TObj>;
    
    public constructor(prev_commands: GPUCommandContainer<TObj>) :=
    self.prev_commands := prev_commands;
    
    public function EnqEvCapacity: integer; abstract;
    
    protected function InvokeParamsImpl(g: CLTaskGlobalData; enq_evs: EnqEvLst): (TObj, cl_command_queue, EventList, QueueRes<TRes>)->DirectEnqRes; abstract;
    public function InvokeParams(g: CLTaskGlobalData; enq_evs: EnqEvLst): EnqueueableEnqFunc<EnqueueableGetCommandInvData<TObj, TRes>>;
    begin
      var enq_f := InvokeParamsImpl(g, enq_evs);
      Result := (data, c, lcq, ev)->enq_f(data.prev_qr.GetRes(c), lcq, ev, data.res_qr);
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override := new QueueResNil(l);
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<TRes,TR>): TR; where TR: QueueRes<TRes>;
    begin
      Result := qr_factory.MakeDelayed(qr->
      begin
        var prev_qr := prev_commands.InvokeToVal(g, l);
        
        var inv_data: EnqueueableGetCommandInvData<TObj, TRes>;
        inv_data.prev_qr  := prev_qr;
        inv_data.res_qr   := qr;
        
        var (enq_ev, enq_act) := EnqueueableCore.Invoke(self, inv_data, g, prev_qr.ResEv, not prev_qr.IsConst);
        Result := new CLTaskLocalData(enq_ev);
        if enq_act<>nil then Result.prev_delegate.AddAction(enq_act);
      end);
    end;
    
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := Invoke(g, l, qr_ptr_factory);
    
  end;
  
  EnqueueableGetPtrCommand<TObj, TRes> = abstract class(EnqueueableGetCommand<TObj,TRes>)
    
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<TRes>; override;
    begin
      Result := nil;
      raise new OpenCLABCInternalException($'Err:Invoke:InvalidToVal');
    end;
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<TRes>; override := inherited InvokeToPtr(g, l);
    protected function InvokeToAny(g: CLTaskGlobalData; l: CLTaskLocalData): QueueRes<TRes>; override := InvokeToPtr(g,l);
    
  end;
  
{$endregion GetCommand}

{$region Kernel}

{$region Implicit}

{%ContainerMethods\Kernel\Implicit.Implementation!ContainerMethods.pas%}

{$endregion Implicit}

{$region Explicit}

{%ContainerMethods\Kernel\Explicit.Implementation!ContainerMethods.pas%}

{$endregion Explicit}

{$endregion Kernel}

{$region MemorySegment}

{$region Implicit}

{%ContainerMethods\MemorySegment\Implicit.Implementation!ContainerMethods.pas%}

{%ContainerMethods\MemorySegment.Get\Implicit.Implementation!ContainerGetMethods.pas%}

{$endregion Implicit}

{$region Explicit}

{%ContainerMethods\MemorySegment\Explicit.Implementation!ContainerMethods.pas%}

{%ContainerMethods\MemorySegment.Get\Explicit.Implementation!ContainerGetMethods.pas%}

{$endregion Explicit}

{$endregion MemorySegment}

{$region CLArray}

{$region Implicit}

{%ContainerMethods\CLArray\Implicit.Implementation!ContainerMethods.pas%}

{%ContainerMethods\CLArray.Get\Implicit.Implementation!ContainerGetMethods.pas%}

{$endregion Implicit}

{$region Explicit}

{%ContainerMethods\CLArray\Explicit.Implementation!ContainerMethods.pas%}

{%ContainerMethods\CLArray.Get\Explicit.Implementation!ContainerGetMethods.pas%}

{$endregion Explicit}

{$endregion CLArray}

{$endregion Enqueueable's}

{$region Global subprograms}

{$region CQ}

function CQ<T>(o: T) := CommandQueue&<T>(o);

{$endregion CQ}

{$region HFQ/HPQ}

{$region Common}

type
  CommandQueueHostCommon<TDelegate> = record
  where TDelegate: Delegate;
    private d: TDelegate;
    
    public procedure ToString(sb: StringBuilder);
    begin
      sb += ': ';
      CommandQueueBase.ToStringWriteDelegate(sb, d);
      sb += #10;
    end;
    
  end;
  
{$endregion Common}

{$region Backgound}

{$region Func}

type
  CommandQueueHostBackgoundFuncBase<T, TFunc> = abstract class(CommandQueue<T>)
  where TFunc: Delegate;
    private data: CommandQueueHostCommon<TFunc>;
    
    public constructor(f: TFunc) := data.d := f;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    protected function ExecFunc(c: Context): T; abstract;
    
    private function MakeNilBody    (prev_d: QueueResComplDelegateData; c: Context; err_handler: CLTaskErrHandler; own_qr: QueueResNil): Action := ()->
    begin
      prev_d.Invoke(c);
      if err_handler.HadError(true) then exit;
      try
        ExecFunc(c);
      except
        on e: Exception do err_handler.AddErr(e);
      end;
    end;
    private function MakeResBody<TR>(prev_d: QueueResComplDelegateData; c: Context; err_handler: CLTaskErrHandler; own_qr: TR): Action; where TR: QueueRes<T>;
    begin
      Result := ()->
      begin
        prev_d.Invoke(c);
        if err_handler.HadError(true) then exit;
        var res: T;
        try
          res := ExecFunc(c);
        except
          on e: Exception do err_handler.AddErr(e);
        end;
        own_qr.SetRes(res);
      end;
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResBaseFactory<TR>; make_body: (QueueResComplDelegateData,Context,CLTaskErrHandler,TR)->Action): TR; where TR: IQueueRes;
    begin
      Result := qr_factory.MakeDelayed(qr->new CLTaskLocalData(
        UserEvent.StartBackgroundWork(l.prev_ev,
          make_body(l.prev_delegate, g.c, g.curr_err_handler, qr),
          g.cl_c{$ifdef EventDebug}, $'body of {self.GetType}'{$endif}
        )
      ));
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil;    override := Invoke(g, l, qr_nil_factory, MakeNilBody);
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, qr_val_factory, MakeResBody&<QueueResVal<T>>);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(g, l, qr_ptr_factory, MakeResBody&<QueueResPtr<T>>);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override := data.ToString(sb);
    
  end;
  
  CommandQueueHostBackgoundFunc<T> = sealed class(CommandQueueHostBackgoundFuncBase<T, ()->T>)
    
    protected function ExecFunc(c: Context): T; override := data.d();
    
  end;
  CommandQueueHostBackgoundFuncC<T> = sealed class(CommandQueueHostBackgoundFuncBase<T, Context->T>)
    
    protected function ExecFunc(c: Context): T; override := data.d(c);
    
  end;
  
function HFQ<T>(f: ()->T) :=
new CommandQueueHostBackgoundFunc<T>(f);
function HFQ<T>(f: Context->T) :=
new CommandQueueHostBackgoundFuncC<T>(f);

{$endregion Func}

{$region Proc}

type
  CommandQueueHostBackgoundProcBase<TProc> = abstract class(CommandQueueNil)
  where TProc: Delegate;
    private data: CommandQueueHostCommon<TProc>;
    
    public constructor(p: TProc) := data.d := p;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    protected procedure ExecProc(c: Context); abstract;
    private function MakeBody(prev_d: QueueResComplDelegateData; err_handler: CLTaskErrHandler; c: Context): Action := ()->
    begin
      prev_d.Invoke(c);
      if err_handler.HadError(true) then exit;
      try
        ExecProc(c);
      except
        on e: Exception do err_handler.AddErr(e);
      end;
    end;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override :=
    new QueueResNil(new CLTaskLocalData(UserEvent.StartBackgroundWork(
      l.prev_ev, MakeBody(l.prev_delegate, g.curr_err_handler, g.c),
      g.cl_c{$ifdef EventDebug}, $'body of {self.GetType}'{$endif}
    )));
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override := data.ToString(sb);
    
  end;
  
  CommandQueueHostBackgoundProc = sealed class(CommandQueueHostBackgoundProcBase<()->()>)
    
    protected procedure ExecProc(c: Context); override := data.d();
    
  end;
  CommandQueueHostBackgoundProcC = sealed class(CommandQueueHostBackgoundProcBase<Context->()>)
    
    protected procedure ExecProc(c: Context); override := data.d(c);
    
  end;
  
function HPQ(p: ()->()) :=
new CommandQueueHostBackgoundProc(p);
function HPQ(p: Context->()) :=
new CommandQueueHostBackgoundProcC(p);

{$endregion Proc}

{$endregion Backgound}

{$region Quick}

{$region Func}

type
  CommandQueueHostQuickFuncBase<T, TFunc> = abstract class(CommandQueue<T>)
  where TFunc: Delegate;
    private data: CommandQueueHostCommon<TFunc>;
    
    public constructor(f: TFunc) := data.d := f;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    protected function ExecFunc(c: Context): T; abstract;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      Result := new QueueResNil(l);
      
      var d := QueueResActionUtils.HandlerWrapStrip(g.curr_err_handler, ExecFunc);
      if l.ShouldInstaCallAction then
        d(g.c) else
        Result.AddAction(d);
      
    end;
    
    private [MethodImpl(MethodImplOptions.AggressiveInlining)]
    function Invoke<TR>(g: CLTaskGlobalData; l: CLTaskLocalData; qr_factory: IQueueResFactory<T,TR>): TR; where TR: QueueRes<T>;
    begin
      
      var d := QueueResActionUtils.HandlerWrap(g.curr_err_handler, ExecFunc);
      if l.ShouldInstaCallAction then
        Result := qr_factory.MakeConst(l, d(g.c)) else
      begin
        Result := qr_factory.MakeDelayed(l);
        Result.AddResSetter(d);
      end;
      
    end;
    protected function InvokeToVal(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResVal<T>; override := Invoke(g, l, qr_val_factory);
    protected function InvokeToPtr(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResPtr<T>; override := Invoke(g, l, qr_ptr_factory);
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override := data.ToString(sb);
    
  end;
  
  CommandQueueHostQuickFunc<T> = sealed class(CommandQueueHostQuickFuncBase<T, ()->T>)
    
    protected function ExecFunc(c: Context): T; override := data.d();
    
  end;
  CommandQueueHostQuickFuncC<T> = sealed class(CommandQueueHostQuickFuncBase<T, Context->T>)
    
    protected function ExecFunc(c: Context): T; override := data.d(c);
    
  end;
  
function HFQQ<T>(f: ()->T) :=
new CommandQueueHostQuickFunc<T>(f);
function HFQQ<T>(f: Context->T) :=
new CommandQueueHostQuickFuncC<T>(f);

{$endregion Func}

{$region Proc}

type
  CommandQueueHostQuickProcBase<TProc> = abstract class(CommandQueueNil)
  where TProc: Delegate;
    private data: CommandQueueHostCommon<TProc>;
    
    public constructor(p: TProc) := data.d := p;
    private constructor := raise new OpenCLABCInternalException;
    
    protected procedure InitBeforeInvoke(g: CLTaskGlobalData; inited_hubs: HashSet<IMultiusableCommandQueueHub>); override := exit;
    
    protected procedure ExecProc(c: Context); abstract;
    
    protected function InvokeToNil(g: CLTaskGlobalData; l: CLTaskLocalData): QueueResNil; override;
    begin
      Result := new QueueResNil(l);
      
      var d := QueueResActionUtils.HandlerWrap(g.curr_err_handler, ExecProc);
      if l.ShouldInstaCallAction then
        d(g.c) else
        Result.AddAction(d);
      
    end;
    
    private procedure ToStringImpl(sb: StringBuilder; tabs: integer; index: Dictionary<object,integer>; delayed: HashSet<CommandQueueBase>); override := data.ToString(sb);
    
  end;
  
  CommandQueueHostQuickProc = sealed class(CommandQueueHostQuickProcBase<()->()>)
    
    protected procedure ExecProc(c: Context); override := data.d();
    
  end;
  CommandQueueHostQuickProcC = sealed class(CommandQueueHostQuickProcBase<Context->()>)
    
    protected procedure ExecProc(c: Context); override := data.d(c);
    
  end;
  
function HPQQ(p: ()->()) :=
new CommandQueueHostQuickProc(p);
function HPQQ(p: Context->()) :=
new CommandQueueHostQuickProcC(p);

{$endregion Proc}

{$endregion Quick}

{$endregion HFQ/HPQ}

{$region CombineQueue's}

{%CombineQueues\Implementation!CombineQueues.pas%}

{$endregion CombineQueue's}

{$endregion Global subprograms}

initialization
finalization
  
  {$ifdef EventDebug}
  EventDebug.FinallyReport;
  {$endif EventDebug}
  
  {$ifdef QueueDebug}
  QueueDebug.FinallyReport;
  {$endif QueueDebug}
  
  {$ifdef WaitDebug}
  foreach var whd: WaitHandlerDirect in WaitDebug.WaitActions.Keys.OfType&<WaitHandlerDirect> do
    if whd.reserved<>0 then
      raise new OpenCLABCInternalException($'WaitHandler.reserved in finalization was <>0');
  WaitDebug.FinallyReport;
  {$endif WaitDebug}
  
end.