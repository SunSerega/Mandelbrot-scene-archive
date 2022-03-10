﻿## uses OpenCLABC;

var A := HPQ(()->raise new Exception('TestOK'));
var B := HPQ(()->lock output do Writeln('TestError1'));
var C := HPQ(()->lock output do Writeln('TestError2'));

Context.Default.SyncInvoke(
  (A + B*C).HandleWithoutRes(e->
  begin
    lock output do Writeln(e);
    Result := true;
  end)
);