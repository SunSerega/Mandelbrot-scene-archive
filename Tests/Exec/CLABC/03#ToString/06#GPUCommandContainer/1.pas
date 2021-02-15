﻿uses OpenCLABC;

begin
  var code := new ProgramCode(Context.Default, '__kernel void p1() { }');
  var k := code['p1'];
  
  k.NewQueue
  .AddExec2(1,1,
    MemorySegmentCCQ.Create(HFQ(()->new MemorySegment(1)))
    .AddQueue(HFQ(()->5))
    .AddProc(b->exit()),
    5
  )
  .Println;
  
end.