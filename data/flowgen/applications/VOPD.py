import AppComposer

# Make Application
VOPD = AppComposer.Application(AppName = "VOPD", StartTime = 0, StopTime = 0)

# Make Threads
VLD = AppComposer.Thread(ThreadName = "VLD")
RunLeDec = AppComposer.Thread(ThreadName = "RunLeDec")
InvScan = AppComposer.Thread(ThreadName = "InvScan")
AcdcPred = AppComposer.Thread(ThreadName = "AcdcPred")
Iquan = AppComposer.Thread(ThreadName = "IQuan")
IDCT = AppComposer.Thread(ThreadName = "IDCT")
ARM = AppComposer.Thread(ThreadName = "ARM")
UpSamp = AppComposer.Thread(ThreadName = "UpSamp")
VopRec = AppComposer.Thread(ThreadName = "VopRec")
Pad = AppComposer.Thread(ThreadName = "Pad")
VopMem = AppComposer.Thread(ThreadName = "VopMem")
StripeMem = AppComposer.Thread(ThreadName = "StripeMem")

# Add Threads to applications
VOPD.addThread(VLD)
VOPD.addThread(RunLeDec)
VOPD.addThread(InvScan)
VOPD.addThread(AcdcPred)
VOPD.addThread(Iquan)
VOPD.addThread(IDCT)
VOPD.addThread(ARM)
VOPD.addThread(UpSamp)
VOPD.addThread(VopRec)
VOPD.addThread(Pad)
VOPD.addThread(VopMem)
VOPD.addThread(StripeMem)

# Add Flows to Threads (Bandwidth must be in Megabytes/second)
VLD.addFlow(AppComposer.Flow(TargetThread = RunLeDec, Bandwidth = 70))
RunLeDec.addFlow(AppComposer.Flow(TargetThread = InvScan, Bandwidth = 362))
InvScan.addFlow(AppComposer.Flow(TargetThread = AcdcPred, Bandwidth = 362))
AcdcPred.addFlow(AppComposer.Flow(TargetThread = Iquan, Bandwidth = 362))
AcdcPred.addFlow(AppComposer.Flow(TargetThread = StripeMem, Bandwidth = 49))
StripeMem.addFlow(AppComposer.Flow(TargetThread = Iquan, Bandwidth = 27))
Iquan.addFlow(AppComposer.Flow(TargetThread = IDCT, Bandwidth = 357))
IDCT.addFlow(AppComposer.Flow(TargetThread = UpSamp, Bandwidth = 353))
ARM.addFlow(AppComposer.Flow(TargetThread = IDCT, Bandwidth = 16))
ARM.addFlow(AppComposer.Flow(TargetThread = Pad, Bandwidth = 16))
UpSamp.addFlow(AppComposer.Flow(TargetThread = VopRec, Bandwidth = 300))
VopRec.addFlow(AppComposer.Flow(TargetThread = Pad, Bandwidth = 313))
Pad.addFlow(AppComposer.Flow(TargetThread = VopMem, Bandwidth = 313))
VopMem.addFlow(AppComposer.Flow(TargetThread = Pad, Bandwidth = 94))

# Save App to JSON
VOPD.toJSON(SaveToFile = True, FileName = "VOPD")
