﻿program prog;
{$apptype windows}
{$reference System.Windows.Forms.dll}

//ToDo Rotate2D - для матриц 3х3 и 4x4 и всех больше добавить выбор - в какой плоскости вращение

//ToDo Rotate3D - поворот относительно 3вектора

//ToDo issue компилятора:
// - #2021

{$region Misc helpers}

function gl_to_pas_t(self: string): string; extensionmethod;
begin
  case self of
    ''+'f':     Result := 'single';
    ''+'d':     Result := 'double';
  end;
end;

type t_descr = (
  (integer,integer), // sz
  string,            // gl_t
  string             // pas_t
);

function GetName(self: t_descr); extensionmethod :=
$'Mtr{self[0][0]}x{self[0][1]}{self[1]}';

function GetRowTName(self: t_descr); extensionmethod :=
$'Vec{self[0][1]}{self[1]}';

function GetColTName(self: t_descr); extensionmethod :=
$'Vec{self[0][0]}{self[1]}';

function GetMltResT(self: (t_descr,t_descr)): t_descr; extensionmethod :=
((self[0][0][0], self[1][0][1]), self[0][1], self[0][2]);

function GetTransposedT(self: t_descr): t_descr; extensionmethod :=
((self[0][1], self[0][0]), self[1], self[2]);

{$endregion Misc helpers}

procedure AddMtrType(res: StringBuilder; t: t_descr; prev_tps: sequence of t_descr);
begin
  res += $'  '+#10;
  res += $'  {t.GetName} = record'+#10;
  
  {$region field's}
  
  for var y := 0 to t[0][1]-1 do
  begin
    res += $'    public ';
    res += Range(0, t[0][0]-1).Select(x->$'val{x}{y}').JoinIntoString(', ');
    res += $': {t[2]};' + #10;
  end;
  
  {$endregion field's}
  
  {$region constructor's}
  
  res += $'    '+#10;
  
  res += $'    public constructor(';
  res +=
    Range(0,t[0][0]-1)
    .Cartesian(Range(0,t[0][1]-1))
    .Select(pos->$'val{pos[0]}{pos[1]}')
    .JoinIntoString(', ');
  res += $': {t[2]});'+#10;
  
  res += $'    begin'+#10;
  
  for var y := 0 to t[0][0]-1 do
    for var x := 0 to t[0][1]-1 do
      res += $'      self.val{y}{x} := val{y}{x};'+#10;
  
  res += $'    end;'+#10;
  
  {$endregion constructor's}
  
  {$region property's}
  
  {$region property val[y,x]}
  
  res += $'    '+#10;
  
  res +=      $'    private function GetValAt(y,x: integer): {t[2]};'+#10;
  res +=      $'    begin'+#10;
  res +=      $'      if cardinal(x) > {t[0][1]-1} then raise new IndexOutOfRangeException(''Индекс "X" должен иметь значение 0..{t[0][1]-1}'');'+#10;
  res +=      $'      if cardinal(y) > {t[0][0]-1} then raise new IndexOutOfRangeException(''Индекс "Y" должен иметь значение 0..{t[0][0]-1}'');'+#10;
  res +=      $'      var ptr: ^{t[2]} := pointer(new IntPtr(@self) + (x*{t[0][0]} + y) * {t[1].Contains(''d'')?8:4} );'+#10;
  res +=      $'      Result := ptr^;'+#10;
  res +=      $'    end;'+#10;
  
  res +=      $'    private procedure SetValAt(y,x: integer; val: {t[2]});'+#10;
  res +=      $'    begin'+#10;
  res +=      $'      if cardinal(x) > {t[0][1]-1} then raise new IndexOutOfRangeException(''Индекс "X" должен иметь значение 0..{t[0][1]-1}'');'+#10;
  res +=      $'      if cardinal(y) > {t[0][0]-1} then raise new IndexOutOfRangeException(''Индекс "Y" должен иметь значение 0..{t[0][0]-1}'');'+#10;
  res +=      $'      var ptr: ^{t[2]} := pointer(new IntPtr(@self) + (x*{t[0][0]} + y) * {t[1].Contains(''d'')?8:4} );'+#10;
  res +=      $'      ptr^ := val;'+#10;
  res +=      $'    end;'+#10;
  
  res += $'    public property val[y,x: integer]: {t[2]} read GetValAt write SetValAt; default;'+#10;
  
  {$endregion property val[y,x]}
  
  {$region static property Identity}
  
  res += $'    '+#10;
  
  res += $'    public static property Identity: {t.GetName} read new {t.GetName}(';
  res +=
    Range(0,t[0][0]-1)
    .Cartesian(Range(0,t[0][1]-1))
    .Select(pos-> pos[0]=pos[1] ? '1.0' : '0.0' )
    .JoinIntoString(', ');
  res += $');'+#10;
  
  {$endregion static property Identity}
  
  {$region property's Row*}
  
  res += $'    '+#10;
  
  for var y := 0 to t[0][0]-1 do
  begin
    res += $'    public property Row{y}: {t.GetRowTName} read new {t.GetRowTName}(';
    res +=
      Range(0,t[0][1]-1)
      .Select(x-> $'self.val{y}{x}' )
      .JoinIntoString(', ');
    res += $') write begin';
    for var x := 0 to t[0][1]-1 do
      res += $' self.val{y}{x} := value.val{x};';
    res += $' end;'+#10;
  end;
  
  res += $'    public property Row[y: integer]: {t.GetRowTName} read ';
  for var y := 0 to t[0][0]-1 do
    res += $'y={y}?Row{y}:';
  res += $'Arr&<{t.GetRowTName}>[y]';
  res += $' write'+#10;
  res += $'    case y of'+#10;
  for var y := 0 to t[0][0]-1 do
    res += $'      {y}: Row{y} := value;'+#10;
  res += $'      else raise new IndexOutOfRangeException(''Номер строчки должен иметь значение 0..{t[0][0]-1}'');'+#10;
  res += $'    end;'+#10;
  
  {$endregion property's Row*}
  
  {$region property's Col*}
  
  res += $'    '+#10;
  
  for var x := 0 to t[0][1]-1 do
  begin
    res += $'    public property Col{x}: {t.GetColTName} read new {t.GetColTName}(';
    res +=
      Range(0,t[0][0]-1)
      .Select(y-> $'self.val{y}{x}' )
      .JoinIntoString(', ');
    res += $') write begin';
    for var y := 0 to t[0][0]-1 do
      res += $' self.val{y}{x} := value.val{y};';
    res += $' end;'+#10;
  end;
  
  res += $'    public property Col[x: integer]: {t.GetColTName} read ';
  for var x := 0 to t[0][1]-1 do
    res += $'x={x}?Col{x}:';
  res += $'Arr&<{t.GetColTName}>[x]';
  res += $' write'+#10;
  res += $'    case x of'+#10;
  for var x := 0 to t[0][1]-1 do
    res += $'      {x}: Col{x} := value;'+#10;
  res += $'      else raise new IndexOutOfRangeException(''Номер столбца должен иметь значение 0..{t[0][1]-1}'');'+#10;
  res += $'    end;'+#10;
  
  {$endregion property's Col*}
  
  {$region property ColPtr[x]}
  
  res += $'    '+#10;
  
  for var x := 0 to t[0][0]-1 do
    res += $'    public property ColPtr{x}: ^{t.GetRowTName} read pointer(IntPtr(pointer(@self)) + {x*t[0][0]*(t[1].Contains(''d'')?8:4)});'+#10;
  res += $'    public property ColPtr[x: integer]: ^{t.GetRowTName} read pointer(IntPtr(pointer(@self)) + x*{t[0][0]*(t[1].Contains(''d'')?8:4)});'+#10;
  
  {$endregion property ColPtr[x]}
  
  {$endregion property's}
  
  {$region method's}
  
  {$region static function Rotate2D}
  
  begin
    var Axiss := Range(1, Min(t[0][0],t[0][1]));
    var ANT: Dictionary<integer,char> := Dict((1,'X'),(2,'Y'),(3,'Z'),(4,'W')); // axiss name table
    
    foreach var plane in Axiss.SelectMany((a,i)->Axiss.Skip(i+1).Select(a2->(a,a2))) do
    begin
      var plane_name := ANT[plane[0]]+ANT[plane[1]];
      var mpc := HSet(plane[0]-1, plane[1]-1); // mtr plane coord
      
      res += $'    '+#10;
      
      res += $'    public static function Rotate{plane_name}cw(rot: double): {t.GetName};'+#10;
      res += $'    begin'+#10;
      res += $'      var sr: {t[2]} := Sin(rot);'+#10;
      res += $'      var cr: {t[2]} := Cos(rot);'+#10;
      res += $'      Result := new {t.GetName}('+#10;
      res += $'        ';
      res +=
        Range(0,t[0][0]-1)
        .Select(y->
          Range(0,t[0][1]-1)
          .Select(x->
          begin
            if (x in mpc) and (y in mpc) then
            begin
              if y=plane[0]-1 then
                Result := x=plane[0]-1 ? ' cr' : '+sr' else
                Result := x=plane[0]-1 ? '-sr' : ' cr';
            end else
              Result := x=y ? '1.0' : '0.0';
          end)
          .JoinIntoString(', ')
        )
        .JoinIntoString(','#10'        ') + #10;
      res += $'      );'+#10;
      res += $'    end;'+#10;
      
      res += $'    public static function Rotate{plane_name}ccw(rot: double): {t.GetName};'+#10;
      res += $'    begin'+#10;
      res += $'      var sr: {t[2]} := Sin(rot);'+#10;
      res += $'      var cr: {t[2]} := Cos(rot);'+#10;
      res += $'      Result := new {t.GetName}('+#10;
      res += $'        ';
      res +=
        Range(0,t[0][0]-1)
        .Select(y->
          Range(0,t[0][1]-1)
          .Select(x->
          begin
            if (x in mpc) and (y in mpc) then
            begin
              if y=plane[0]-1 then
                Result := x=plane[0]-1 ? ' cr' : '-sr' else
                Result := x=plane[0]-1 ? '+sr' : ' cr';
            end else
              Result := x=y ? '1.0' : '0.0';
          end)
          .JoinIntoString(', ')
        )
        .JoinIntoString(','#10'        ') + #10;
      res += $'      );'+#10;
      res += $'    end;'+#10;
      
    end;
    
  end;
  
  {$endregion static function Rotate2D}
  
  {$region function Println}
  
  res += $'    '+#10;
  
  res +=      $'    public function Println: {t.GetName};'+#10;
  res +=      $'    begin'+#10;
  res +=      $'      var ElStrs := new string[{t[0][0]},{t[0][1]}];' + #10;
  res +=      $'      for var y := 0 to {t[0][0]}-1 do' + #10;
  res +=      $'        for var x := 0 to {t[0][1]}-1 do' + #10;
  res +=      $'          ElStrs[y,x] := (Sign(val[y,x])=-1?''-'':''+'') + Abs(val[y,x]).ToString(''f2'');' + #10;
  
  res +=      $'      var MtrElTextW := ElStrs.OfType&<string>.Max(s->s.Length);' + #10;
  res +=      $'      var PrintlnMtrW := MtrElTextW*{t[0][1]} + {2*t[0][1]}; // +2*(Width-1) + 2;' + #10;
  
  res +=      $'      ' + #10;
  
  res +=      $'      writeln( ''{ char($250C) }'' + #32*PrintlnMtrW + ''{ char($2510) }'' );' + #10;
  for var y := 0 to t[0][0]-1 do
  begin
    res +=    $'      writeln( ''{ char($2502) } '', ';
    for var x := 0 to t[0][1]-1 do
    begin
      res += $'ElStrs[{y},{x}].PadLeft(MtrElTextW)';
      if x<>t[0][1]-1 then res += ', '', '', ';
    end;
    
    res +=    $', '' { char($2502) }'' );' + #10;
  end;
  res +=      $'      writeln( ''{ char($2514) }'' + #32*PrintlnMtrW + ''{ char($2518) }'' );' + #10;
  
  res +=      $'      ' + #10;
  
  res +=      $'      Result := self;'+#10;
  res +=      $'    end;'+#10;
  
  {$endregion function Println}
  
  {$endregion method's}
  
  {$region operator's}
  
  {$region arithmetics}
  
  res += $'    '+#10;
  
  res += $'    public static function operator*(m: {t.GetName}; v: {t.GetRowTName}): {t.GetColTName} := new {t.GetColTName}(';
  res +=
    Range(0,t[0][0]-1)
    .Select(y->
      Range(0,t[0][1]-1)
      .Select(x->
        $'m.val{y}{x}*v.val{x}'
      ).JoinIntoString('+')
    ).JoinIntoString(', ');
  res += $');'+#10;
  
  res += $'    public static function operator*(v: {t.GetColTName}; m: {t.GetName}): {t.GetRowTName} := new {t.GetRowTName}(';
  res +=
    Range(0,t[0][1]-1)
    .Select(x->
      Range(0,t[0][0]-1)
      .Select(y->
        $'m.val{y}{x}*v.val{y}'
      ).JoinIntoString('+')
    ).JoinIntoString(', ');
  res += $');'+#10;
  
  {$endregion arithmetics}
  
  {$region operator implicit}
  
  foreach var t2 in prev_tps do
  begin
    res += $'    '+#10;
    
    res += $'    public static function operator implicit(m: {t2.GetName}): {t.GetName} := new {t.GetName}(';
    res +=
      Range(0,t[0][0]-1)
      .Cartesian(Range(0,t[0][1]-1))
      .Select(pos-> (pos[0]<t2[0][0]) and (pos[1]<t2[0][1]) ? $'m.val{pos[0]}{pos[1]}' : '0.0' )
      .JoinIntoString(', ');
    res += $');'+#10;
    
    res += $'    public static function operator implicit(m: {t.GetName}): {t2.GetName} := new {t2.GetName}(';
    res +=
      Range(0,t2[0][0]-1)
      .Cartesian(Range(0,t2[0][1]-1))
      .Select(pos-> (pos[0]<t[0][0]) and (pos[1]<t[0][1]) ? $'m.val{pos[0]}{pos[1]}' : '0.0' )
      .JoinIntoString(', ');
    res += $');'+#10;
    
  end;
  
  {$endregion operator implicit}
  
  {$endregion operator's}
  
  res += $'    '+#10;
  
  res += $'  end;'+#10;
  if t[0][0]=t[0][1] then
    res += $'  Mtr{t[0][0]}{t[1]} = {t.GetName};'+#10;
  
end;

{$region extensionmethod's}

procedure AddMtrMlt(res: StringBuilder; t1,t2: t_descr);
begin
  
  var rt := (t1,t2).GetMltResT;
  res += $'    '+#10;
  
  res +=      $'    function operator*(m1: {t1.GetName}; m2: {t2.GetName}): {rt.GetName}; extensionmethod;'+#10;
  res +=      $'    begin'+#10;
  for var y := 0 to rt[0][0]-1 do
    for var x := 0 to rt[0][1]-1 do
    begin
      res +=  $'      Result.val{y}{x} := ';
      res +=
        Range(0, t1[0][1]-1)
        .Select(i-> $'m1.val{y}{i}*m2.val{i}{x}' )
        .JoinIntoString(' + ');
      res += ';'#10;
    end;
  res +=      $'    end;'+#10;
  
end;

procedure AddTranspose(res: StringBuilder; t: t_descr);
begin
  
  if t[0][0]<=t[0][1] then
    res += '  '#10;
  res += $'  function Transpose(self: {t.GetName}); extensionmethod :='+#10;
  res += $'  new {t.GetTransposedT.GetName}(';
  res +=
    Range(0,t[0][1]-1)
    .Cartesian(Range(0,t[0][0]-1))
    .Select(pos-> $'self.val{pos[1]}{pos[0]}' )
    .JoinIntoString(', ');
  res += ');'#10;
  
end;

{$endregion extensionmethod's}

begin
  try
    var res := new StringBuilder;
    
    res += #10;
    res += '  {$region Mtr}'#10;
    
    var t_table: sequence of t_descr :=
      Range(2,4)
      .Cartesian(Range(2,4))
      .SelectMany(sz->
        Arr&<string>('f','d')
        .Select(t->(sz,t,t.gl_to_pas_t))
      ).OrderBy(t->t[0][0]=t[0][1]?integer.MinValue:t[0][0]+t[0][1])
      .OrderByDescending(t->t[1])
      .ToArray
    ;
    
    foreach var t in t_table.Numerate(0) do
      AddMtrType(res, t[1], t_table.Take(t[0]));
    
    res += '  '#10;
    res += '  {$endregion Mtr}'#10;
    res += '  '#10;
    res += '  {$region MtrMlt}'#10;
    
    foreach var t1 in t_table do
      foreach var t2 in t_table do
        if t1[0][1]=t2[0][0] then
          AddMtrMlt(res, t1,t2);
    
    res += '  '#10;
    res += '  {$endregion MtrMlt}'#10;
    res += '  '#10;
    res += '  {$region MtrTranspose}'#10;
    
    foreach var t in t_table do
      AddTranspose(res, t);
    
    res += '  '#10;
    res += '  {$endregion MtrTranspose}'#10;
    
    res += '  ';
    System.Windows.Forms.Clipboard.SetText(res.ToString.Replace(#10,#13#10));
    System.Console.Beep;
  except
    on e: Exception do
    begin
      writeln(e);
      readln;
    end;
  end;
end.