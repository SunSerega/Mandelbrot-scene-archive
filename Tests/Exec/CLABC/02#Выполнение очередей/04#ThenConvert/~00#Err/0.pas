﻿## uses OpenCLABC;

Context.Default.SyncInvoke(
  HQFQ(()->5).ThenConstConvert(i->
  begin
    Result := i;
    raise new Exception('TestOK');
  end)
);