
from PE import PE

class Structure:

    def __init__(self, StructureType, AmountOfPEs):
        
        self.StructureType = StructureType
        self.BaseNoCPos = None  # To be set when Platform.addStructure() is called
        self.AmountOfPEs = AmountOfPEs

        if str(StructureType).casefold() == "crossbar":
            #self.PEs = [PE(PEPos=i, AppID=None, ThreadID=None, InjectorClockFrequency=None) for i in range(AmountOfPEs)]
            self.PEs = [PE(PEPos = i, BaseNoCPos = None, StructPos = i, CommStructure = "Crossbar") for i in range(self.AmountOfPEs)]
        elif str(StructureType).casefold() == "bus":
            self.PEs = [PE(PEPos = i, BaseNoCPos = None, StructPos = i, CommStructure = "Bus") for i in range(self.AmountOfPEs)]
        else:
            print("Given structure type \"" + str(StructureType) + "\" not recognized")
            exit(1)
            
            
    def __str__(self):
    
        returnString = ""
        
        returnString += "StructureType: " + str(self.StructureType) + "\n"
        returnString += "AmountOfPEs: " + str(self.AmountOfPEs) + "\n"
        returnString += "AddressInBaseNoC: " + str(self.AddressInBaseNoC) + "\n"
        returnString += "PE Addresses: " + str([PE.PEPos for PE in self.PEs])
        
        return returnString


class Bus(Structure):

    def __init__(self, AmountOfPEs):
        Structure.__init__(self, StructureType = "Bus", AmountOfPEs = AmountOfPEs)


class Crossbar(Structure):

    def __init__(self, AmountOfPEs):
        Structure.__init__(self, StructureType = "Crossbar", AmountOfPEs = AmountOfPEs)
        
        