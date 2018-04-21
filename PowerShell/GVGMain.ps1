### GVG ATEM Controler
### version:0.2 - still experimenting with functionality
### By: Ian Morrish
###
### v0.4 Added LED status for Key Bus showing Aux or MediaPlayer slot. Introduced bug in Program/Preview LED updates sometimes not working.
###
### v0.3 Added button LED mapping to ATEM input ID using JSON config file (requires update to Arduino sketch for LED fast clear of program or preview
###
### v0.2 enabled Key Bus to be used for Aux1-6, MP1-2 and USK/DSK fill source by holding "Positioner" button for 2 seconds (until led flashes) and then sellecting pattern
###      hold down "Editor Enable" to enable shift for key bus 2nd option (top row is Media slot or macro number, bottom row is alternative inputs for Aux and keyers)
### v0.1 Program/preview, Mix/dip & Wipe/DVE (hold for 2 seconds for dip or dve), FTB and T-Bar working
#
# GVGKeys.json defines ATEM Commands or function that is called when button is pushed
# You need to update the path in the LoadXkeys function
#
# switcherlib.dll and Solid.Arduino.dll need to be copied from https://ianmorrish.wordpress.com
#
#Find Arduino COM Port
#Genuine Arduino will be a serial port but clone will be a USB serial port emulator
#region Arduino setup
$PortName = (Get-WmiObject Win32_SerialPort | Where-Object { $_.Name -match "Arduino"}).DeviceID
if ( $PortName -eq $null ) {
    $DeviceName = (Get-WmiObject Win32_PnPEntity | Where-Object { $_.Description -match "USB-SERIAL CH340"}).Caption
    if ( $DeviceName -ne $null ) {
        $PortName = $DeviceName.Split("(")[1].Trim(")")
    }
    else {
        $DeviceName = (Get-WmiObject Win32_PnPEntity | Where-Object { $_.Description -match "USB Serial Device"}).Caption
        if ( $DeviceName -ne $null ) {
            $PortName = $DeviceName.Split("(")[1].Trim(")")
        }
  }

}
write-host "Arduino found on $($PortName)" 
add-type -path '.\Documents\WindowsPowerShell\Solid.Arduino.dll'
$connection = New-Object Solid.Arduino.SerialConnection($PortName,[Solid.Arduino.SerialBaudRate]::Bps_57600)
$session = New-Object Solid.Arduino.ArduinoSession($connection, 2000)
Start-Sleep -Seconds 6
$session.GetFirmware()
#endregion

# flash all the LED's just for fun
function demoLeds(){
    $demo = @(38,36,34,32,1,3,5,7,6,4,33,35,37,39,13,15,14,12,0,2,30,28,26,24,9,8,11,10,51,53,50,54,52,49,48,44,40,25,17,16,21,23,18,22,19,20,43,41,61,63,45,59,57,62,60,58,64,66,70,69,65,79,75,77,78,67,71,68,72,74,73)
    for($i=0; $i -le 70; $i++){
      $session.SendStringData("2,$($demo[$i])")
      Start-Sleep -m 50
      $session.SendStringData("1,$($demo[$i])")
    }
}
demoLeds

#region ATEMSetup
function ConnectToATEM()
{
    Try{
        $ATEMipAddress = (Get-ItemProperty -path 'HKCU:\Software\Blackmagic Design\ATEM Software Control').ipAddress
        $DocumentsPath = [Environment]::GetFolderPath("MyDocuments") + '\windowspowershell\SwitcherLib.dll'
        add-type -path $DocumentsPath
        
        $Global:atem = New-Object SwitcherLib.Switcher($ATEMipAddress)
        $atem.Connect()
        }
        catch{
        write-host "Can't connect to ATEM on $($ATEMipAddrss)."
        Write-Host "ATEM controle software must be installed and have connected to switcher at least one time"
        Stop
        }
}
function CreateATEMObjects()
{
    $me=$atem.GetMEs()
    $Global:me1=$me[0]
    $Global:me2=$me[1]
    $Global:activeME = $me1
    #$Global:activeME = $

    $MediaPlayers = $atem.GetMediaPlayers()
    $Global:MP1=$MediaPlayers[0]
    $Global:MP2=$MediaPlayers[1]

    $Global:Auxs=$atem.GetAuxInputs()
    $Global:aux1 = $auxs[0]

    $Global:USK = $ATEM.GetKeys()
    $Global:activeUSK = $USK[0]
}
ConnectToATEM
CreateATEMObjects
#endregion

$Global:KeyBusMode="Aux1"
$Global:ShiftMode=$false
$Global:EditorMode=$false
$Global:TransitionType = $Global:activeME.TransitionStyle
$Global:TransitionSelection = $activeme.TransitionSelection
$Global:USKTransitionType = $Global:activeUSK.Type
$Global:NextTransition = $Global:activeME.TransitionSelection
$Global:PreviewTransitionStatus = $ActiveME.PreviewTransition
$Global:Aux1Source = $aux1.Source
$Global:MP1Source = $MP1.MediaStill
$Global:MP2Source = $MP2.MediaStill
#T-Bar
$Global:TbarLastFramPosition = 0
$Global:TransitionDirection = "normal"
$Global:PatternCtrlMode="WipePattern"

function LoadXkeys(){
    $gvgFile = ConvertFrom-Json (get-content "OneDrive\PowerShell\GVG100\gvgkeys.json" -raw)
    $Global:atemCommands = New-Object System.Collections.Hashtable
    $Global:atemInputMapping = New-Object System.Collections.Hashtable
    # Map buttons to PowerShell commands
    foreach($key in $gvgFile.keys){
        $atemCommands.add($key.Value,$key.Command)
    }
    # map button LED's to ATEM Inputs
    foreach($key in $gvgFile.Mapping){
        $atemInputMapping.add($key.Key,$key.Input)
    }
}
LoadXKeys


function Handlekey($keyId){
    #write-host "Key pressed - $($keyId)"
    $analogPot = $keyid.split(',')
    if($atemCommands.ContainsKey($keyId))
    {
        try{invoke-expression  $atemCommands.Get_Item($keyId)}
        catch{write-host "error: $($error)"}
    }
    elseif($analogPot[0] -eq "Pot2"){
        $b = $analogPot[1]-as [int]
        #Write-host $b
        tbar $b
    }
    else{
        write-host $keyId
    }
}
Unregister-Event -SourceIdentifier eventMessage -ErrorAction SilentlyContinue #incase we are re-running the script
$ArduinoEvent = Register-ObjectEvent -InputObject $session -EventName MessageReceived -SourceIdentifier eventMessage -Action {Handlekey($eventArgs.Value.Value.text)}

$previewLEDs = @(38,36,34,32,1,3,5,7,6,4)
$programLEDs = @(33,35,37,39,13,15,14,12,0,2)
$bussLEDs = @(30,28,26,24,9,8,11,10,51,53)

#Turn on initial state display
$Global:activeME = $me1
$Global:Program = $activeME.Program
$Global:Preview = $activeME.Preview
if($Global:Program -gt 0 -And $Global:Program -lt 9){
    #turn on new program led
    $session.SendStringData("2,$($programLEDs[$Global:Program-1])")
}
if($Global:Preview -gt 0 -And $Global:Preview -lt 9){
      #turn on new Preview led
      $session.SendStringData("2,$($previewLEDs[$Global:Preview-1])")
}
#set next transition to bkgd
$session.SendStringData("2,49")
#Show ME1 LED
$session.SendStringData("2,63")

function monitor(){
    #Program bus
    [Int32]$CurrentProgram = $Global:activeME.Program # | get-member
    if($Global:Program -ne $CurrentProgram){
        #clear program leds
        $session.SendStringData("6,program")
        if($atemInputMapping.ContainsValue($CurrentProgram)){
            $keys=$atemInputMapping.GetEnumerator() | ?{ $_.Value -eq $CurrentProgram }
            $key=$keys[0].Key
            if($key -lt 11){
                $session.SendStringData("2,$($programLEDs[$key-1])")
            }
            else{
                $session.SendStringData("4,$($programLEDs[$key-11])")
            }
        }

        $Global:Program = $CurrentProgram
    }

    #Preview bus
    [Int32]$CurrentPreview = $Global:activeME.Preview
    if($Global:Preview -ne $CurrentPreview){
        #clear program leds
        $session.SendStringData("6,preview")
        if($atemInputMapping.ContainsValue($CurrentPreview)){
            $keys=$atemInputMapping.GetEnumerator() | ?{ $_.Value -eq $CurrentPreview }
            $key=$keys[0].Key # Value
            if($key -lt 11){
                $session.SendStringData("2,$($previewLEDs[$key-1])")
            }
            else{
                $session.SendStringData("4,$($previewLEDs[$key-11])")
            }
        }

        $Global:Preview = $CurrentPreview
    }

    #Transition Mode LED's
    if($Global:TransitionType -ne $Global:activeME.TransitionStyle){
        switch($Global:TransitionType){
            Mix{$session.SendStringData("1,54")}
            Dip{$session.SendStringData("3,54")}
            Wipe{$session.SendStringData("1,52")}
            DVE{$session.SendStringData("3,52")}
            
        }
        switch($Global:activeME.TransitionStyle){
            Mix{$session.SendStringData("2,54")}
            Dip{$session.SendStringData("4,54")}
            Wipe{$session.SendStringData("2,52")}
            DVE{$session.SendStringData("4,52")}
        }

        $Global:TransitionType = $Global:activeME.TransitionStyle
    }

    #USK Mode LED's
    if($Global:USKTransitionType -ne $Global:activeUSK.Type){
        switch($Global:USKTransitionType){
            Luma{$session.SendStringData("1,21")}
            Chroma{$session.SendStringData("1,23")}
            Pattern{$session.SendStringData("1,18")}
            DVE{$session.SendStringData("1,22")}
            
        }
        switch($Global:activeUSK.Type){
            Luma{$session.SendStringData("2,21")}
            Chroma{$session.SendStringData("2,23")}
            Pattern{$session.SendStringData("2,18")}
            DVE{$session.SendStringData("2,22")}
        }

        $Global:USKTransitionType = $Global:activeUSK.Type
    }
    
    #Next Transition LED status
    if($Global:NextTransition -ne $Global:activeME.TransitionSelection){
        switch($Global:activeME.TransitionSelection){
        1{$session.SendStringData("2,49");$session.SendStringData("1,48");break}
        2{$session.SendStringData("1,49");$session.SendStringData("2,48");break}
        3{$session.SendStringData("2,49");$session.SendStringData("2,48");break}
        }
    $Global:NextTransition = $Global:activeME.TransitionSelection
    }

    #Preview Transition status
    if($Global:PreviewTransitionStatus -ne $ActiveME.PreviewTransition){
        if($ActiveME.PreviewTransition){$session.SendStringData("2,45")}
        else{$session.SendStringData("1,45")}
     $Global:PreviewTransitionStatus = $ActiveME.PreviewTransition
     }
     #KeyBus LED's
     switch($Global:KeyBusMode){
     Aux1{
        if($Global:Aux1Source -ne $aux1.Source){
            #clear Bus LED's
            $session.SendStringData("6,keybus")
            if($atemInputMapping.ContainsValue([Int32]$aux1.Source)){
                $keys=$atemInputMapping.GetEnumerator() | ?{ $_.Value -eq $aux1.Source }
                $key=$keys[0].Key
                if($key -lt 11){
                    $session.SendStringData("2,$($bussLEDs[$key-1])")
                }
                else{
                $session.SendStringData("4,$($bussLEDs[$key-11])")
                }
            }

            $Global:Aux1Source = $aux1.Source
        }
            
     }
     MP1{
        if($Global:MP1Source -ne $MP1.MediaStill){
            #clear Bus LED's
            $session.SendStringData("6,keybus")
            if($MP1.MediaStill -lt 11){
                $session.SendStringData("2,$($bussLEDs[$MP1.MediaStill])")
            }
            else{
                $session.SendStringData("4,$($bussLEDs[$MP1.MediaStill-10])")
            }

            $Global:MP1Source = $MP1.MediaStill
        }
    }
         MP2{
        if($Global:MP2Source -ne $MP2.MediaStill){
            #clear Bus LED's
            $session.SendStringData("6,keybus")
            if($MP1.MediaStill -lt 11){
                $session.SendStringData("2,$($bussLEDs[$MP2.MediaStill])")
            }
            else{
                $session.SendStringData("4,$($bussLEDs[$MP2.MediaStill-10])")
            }

            $Global:MP1Source = $MP1.MediaStill
        }
    }

    }
   
}

$timer = New-Object System.Timers.Timer
$timer.Interval = 100
$timer.AutoReset = $true
$sourceIdentifier = "TimerJob"
Unregister-Event $sourceIdentifier -ErrorAction SilentlyContinue
$timer.stop()
$start = Register-ObjectEvent -InputObject $timer -SourceIdentifier $sourceIdentifier -EventName Elapsed -Action {monitor} #$timeraction
$timer.start()

function normalize($value, $min, $max) {
    if($value -gt 254){$value=255}
    if($value -lt 2){$value=0}
	$normalized = [math]::Round(($value - $min) / ($max - $min),2)
	return $normalized
}

function tbar($value){
  $frame = normalize $value 0 255
  If($frame -ne $Global:TbarLastFramPosition){
    $Global:TbarLastFramPosition = $frame
    #Write-Host $event.value.Level
    if($Global:TransitionDirection -eq "normal"){
            $Global:ActiveME.TransitionPosition = $frame
            #Write-Host "Frame normal direction = $($frame)"
        }
        Else{
            $Global:ActiveME.TransitionPosition = (1-$frame)
            #Write-Host "Frame reverse direction = $($frame)"
        }
            if($frame -eq 0){
            $Global:TransitionDirection = "normal"
            #Write-Host "Direction = normal"
        }
        elseif($frame -eq 1){
            $Global:TransitionDirection = "reverse"
            #Write-Host "Direction = reverse"
        }
  }

}
$PatternName = $([SwitcherLib.enumMixerPatternStyle]::LeftToRightBar,[SwitcherLib.enumMixerPatternStyle]::TopToBottomBar,[SwitcherLib.enumMixerPatternStyle]::HorizontalBarnDoor,[SwitcherLib.enumMixerPatternStyle]::VerticalBarnDoor,[SwitcherLib.enumMixerPatternStyle]::TopLeftDiagonal,[SwitcherLib.enumMixerPatternStyle]::TopRightBox,[SwitcherLib.enumMixerPatternStyle]::TopLeftBox,[SwitcherLib.enumMixerPatternStyle]::RectangleIris,[SwitcherLib.enumMixerPatternStyle]::CircleIris,[SwitcherLib.enumMixerPatternStyle]::DiamondIris)
$PatternMode = $("Aux1","Aux2","Aux3","MP1","MP2","Macro","DSK1","DSK2","USK1","USK2")
$PatternLEDs = $(70,69,65,79,75,68,71,67,78,77)
function PatternControl($patternNumber){
    #clear current leds
        $session.SendStringData("7,0")

    switch($Global:PatternCtrlMode){
        USKPattern{
                    $Global:activeUSK.Pattern = $PatternName[$patternNumber-1]
                    $session.SendStringData('3,18')
        }
        WipePattern{
                    $Global:activeME.TransitionWipePattern = $PatternName[$patternNumber-1]
        }
        BusKeyMode{
                    $Global:KeyBusMode= $PatternMode[$patternNumber-1]
                    $session.SendStringData("4,$($PatternLEDs[$patternNumber-1])")
                    #clear Bus LED's
                    $session.SendStringData("6,keybus")
        }

    }
}

function buskey($key){
    if($Global:ShiftMode){$key=$key+10}
    switch($Global:KeyBusMode){
    "Aux1"{if($Key -eq 9){$key=10010};if($Key -eq 10){$key=10011};$Aux1.Source = $key;write-host "Aux set to $($Key)"}
    "MP1"{$MP1.MediaStill = $Key-1}
    "MP2"{$MP2.MediaStill = $Key-1}
    "Macro"{$Global:MacroToRun = $atem.RunMacro($Key)}
    "DSK1Src"{}
    "DSK2Src"{}
    "USK1Src"{$activeUSK.InputFill = $Key}

    }
}
function ShiftModeToggle(){
    if($Global:ShiftMode){
        $session.SendStringData('3,76')
        $Global:ShiftMode = $false
        $session.SendStringData('1,76')
    }
    else{
        $session.SendStringData('4,76')
        $Global:ShiftMode = $true
    }
}
function ToggleNextTransition($item){
    #Next Transition is a bit mask for Background, USK1, USK2, USK3, USK4 (1,2,4,8 respectivly)
    switch($item){
        bkgd{
        if($Global:activeME.TransitionSelection -ne 1){# don't toggle bit if it is the only thing enabled
            $Global:activeME.TransitionSelection = ($Global:activeME.TransitionSelection -bxor 1)
            }
        }
        key{
        if($Global:activeME.TransitionSelection -ne 2){# don't toggle bit if it is the only thing enabled
            $Global:activeME.TransitionSelection = ($Global:activeME.TransitionSelection -bxor 2)
            }
        }
    }
}

function ToggleActiveME(){
    if($Global:activeME -eq $me1){
        $Global:activeME = $me2;
        $session.SendStringData("4,63")
    }
    else {
        $Global:activeME = $me1;
        $session.SendStringData("3,63")

    }
}

function USKAutoTransition(){
        $Global:activeME.TransitionSelection=2
        Start-Sleep -Milliseconds 1
        $me1.AutoTransition()
        Start-Sleep -Milliseconds 10 #give it a chance to start
        Start-Sleep 2
        #Key is now onair so remove from next transition (Turn on BKGD)
        $Global:activeME.TransitionSelection=1 
}
<#
$session.SendStringData("2,1")
$session.SendStringData("4,36")
$session.SendStringData("6,preview")
#blink single LED
$session.SendStringData("4,77")

#test blinking row
$session.SendStringData("5,1")
start-sleep 8
$session.SendStringData("5,0")

#stop blinking single LED
$session.SendStringData("3,77")

#turn off pattern LED's
$session.SendStringData("7,0")

#read analog values that have changed
$session.SendStringData("9,1")
#>
function allLEDs (){
for($i=0; $i -le 80; $i++){
  $session.SendStringData("2,$($i)")
  Start-Sleep -m 100
  $session.SendStringData("1,$($i)")
}
}

function DVEFly(){
$activeME.DVEInputFill = 1
$USK=$atem.GetKeys()
$usk[0].InputFill = 1
$usk[0].DVEBorderWidthOut = .5
$usk[0].DVEBorderWidthIn = 0
$usk[0].FlyPositionX = 8
$usk[0].FlyPositionY = 4
$usk[0].FlySizeX = 1
$usk[0].FlySizey = 1
}

function blinkKeyBus($cmd){
    foreach($led in $bussLEDs){
        $session.SendStringData("$($cmd),$($led)")
        start-sleep -Milliseconds 100
    }
}
function allOff(){
for($i=0;$i -lt 80; $i++){
$session.SendStringData("3,$($i)")
$session.SendStringData("1,$($i)")
} 
}

function Codeexit(){
    Unregister-Event -SourceIdentifier eventMessage -ErrorAction SilentlyContinue #incase we are re-running the script
    Unregister-Event $sourceIdentifier -ErrorAction SilentlyContinue
    $timer.stop()
}