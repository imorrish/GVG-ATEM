#include <Wire.h>
#include <Keypad.h>
#include <Firmata.h>

#define BITSB 8 
#define TOLERANCE 10
#define  Data0       23          //15
#define  Data1       25          //16
#define  Data2       27          //17
#define  Data3       29          //19
#define  Data4       31          //
#define  Data5       33          //
#define  Data6       35          //
#define  Data7       37          //
#define  W0          22          //
#define  W1          24          //
#define  W2          26          //
#define  W3          28          //
#define  AnalRead    34          //5
#define  AnalConv    36          //7
#define  LEDwrite    30          //18
#define  buttread    32          //20
#define  Display    38           //9

#define ON 1
#define OFF 0
  
  int DecoderPins[] = {22,24,26,28};
  int BlinkCount = 0;
  int BlinkStatus = 0;
  byte AnalogPreviousValues [] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

  
// Keypad setup
//
const byte ROWS = 8;
const byte COLS  = 10;
char keys[ROWS][COLS] = {
  {'1','9','h','p','x','G','O','W','$','>'},
  {'2','a','i','q','y','H','P','X','%','?'},
  {'3','b','j','r','A','I','Q','Y','^','/'},
  {'4','c','k','s','B','J','R','Z','&','-'},
  {'5','d','l','t','C','K','S','~','*','['},
  {'6','e','m','u','D','L','T','!','(',']'},
  {'7','f','n','v','E','M','U','@',')',';'},
  {'8','g','o','w','F','N','V','#','<','+'}
};
byte rowPins[ROWS] = {23,25,27,29,31,33,35,37};
byte colPins[COLS] = {2,3,4,5,6,8,9,10,11,12}; //not actually using these pins, just binary conversion to drive encoder

//BCD to drive decoder pins for LED and Keyboard row select
byte BCD[16][4] ={{0,0,0,0},
{1,0,0,0},
{0,1,0,0},
{1,1,0,0},
{0,0,1,0},
{1,0,1,0},
{0,1,1,0},
{1,1,1,0},
{0,0,0,1},
{1,0,0,1},
{0,1,0,1},
{1,1,0,1},
{0,0,1,1},
{1,0,1,1},
{0,1,1,1},
{1,1,1,1}}; //BCD code

int bussLEDs[] =    {30,28,26,24,9,8,11,10,51,53};
int previewLEDs[] = {38,36,34,32,1,3,5,7,6,4};

Keypad keypad = Keypad( makeKeymap(keys), rowPins, colPins, ROWS, COLS );
void keypadEvent(KeypadEvent key){
    String echoMsg; 
    String action;    
    switch (keypad.getState()){
      case PRESSED:{
        action = "Down,";
        echoMsg = action+key;
        Firmata.sendString(echoMsg.c_str());
        break;
      }
      case HOLD:{
        action = "Hold,";
        echoMsg = action+key;
        Firmata.sendString(echoMsg.c_str());
        break;
      }
    }
}

//Led status array
#define LedBITSB 8            // number of bits per byte, used for code clarity
#define LedDATABITS 80
const int arrayLen = (int)((LedDATABITS-1)/LedBITSB) + 1;
//byte LEDArray[arrayLen];        // for GVG100, length is 10 and that could hold 80 values  
int LEDArray[LedDATABITS];
int BlinkLEDArray[LedDATABITS];

void initLEDarray(){
  for(int i = 0; i < LedDATABITS; i++) {
    LEDArray[i] = 0;
  }
}
void initBlinkLEDarray(){
for(int i = 0; i < LedDATABITS; i++) {
    BlinkLEDArray[i] = 0;
  }
}

void stringCallback(char *myString)
{
  String lcdString=String(myString);
  int Line1Index=lcdString.indexOf(',');
  int Line2Index=lcdString.indexOf(',', Line1Index+1); // more than one comma?

  String Line1 = lcdString.substring(0,Line1Index);
  String Line2 = lcdString.substring(Line1Index+1);
  // update led
  int LEDSelRow = 0;
  LEDSelRow = Line2.toInt()/8; //find row number - this rounds automatically
  //SelectLedRow(LEDSelRow);
  int LedSelCol=0;
  LedSelCol= (Line2.toInt() % 8); //use MOD to find bit position
  digitalWrite(buttread, HIGH);
  switch(Line1.toInt())
  {
  case 1:
    {
      //set LED off
      LEDArray[Line2.toInt()]=0;
      WriteData();
      for(int i = 0; i < 8; i++) {
        digitalWrite(rowPins[i] ,LEDArray[(LEDSelRow*8)+i]);
      }
      delay(1);
      DecoderOut(LEDSelRow);
      delay(1);
      break;
    }
  case 2:
    {
      //Set LED On
      LEDArray[Line2.toInt()]=1;
      WriteData();
      for(int i = 0; i < 8; i++) {
        digitalWrite(rowPins[i] ,LEDArray[(LEDSelRow*8)+i]);
      }
      delay(1);
      DecoderOut(LEDSelRow);
      delay(1);
      break;
    }
    case 3:
    {
      //set blink off
      BlinkLEDArray[Line2.toInt()]=0;
      LEDArray[Line2.toInt()]=0;
      break;
    }
    case 4:
    {
      //set blink on
      BlinkLEDArray[Line2.toInt()]=1;
      break;
    }
    case 5:
    {
      if(BlinkStatus == 1){
        //leds are already on so update blinking and set state off
        blinkLEDs();
        BlinkStatus = 0;
      }
      for(int i = 0; i < 10; i++) {
        BlinkLEDArray[bussLEDs[i]]=Line2.toInt();
      }
      break;
    }
    case 6:
    {
      if(BlinkStatus == 1){
        //leds are already on so update blinking and set state off
        blinkLEDs();
        BlinkStatus = 0;
      }
      for(int i = 0; i < 10; i++) {
        BlinkLEDArray[previewLEDs[i]]=Line2.toInt();
      }
      break;
    }
    case 9:
    {
      readAnalogValues();
      break;
    }
  }
}
void SetDataBit(int bit){
  switch(bit)
  {
    case 0:
    {
      digitalWrite(Data0, HIGH);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, LOW);
      break;
    }
    case 1:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, HIGH);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, LOW);
      break;
    }
    case 2:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, HIGH);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, LOW);
      break;
    }
    case 3:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, HIGH);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, LOW);
      break;
    }
    case 4:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, HIGH);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, LOW);
      break;
    }
    case 5:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, HIGH);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, LOW);
      break;
    }
    case 6:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, HIGH);
      digitalWrite(Data7, LOW);
      break;
    }
    case 7:
    {
      digitalWrite(Data0, LOW);
      digitalWrite(Data1, LOW);
      digitalWrite(Data2, LOW);
      digitalWrite(Data3, LOW);
      digitalWrite(Data4, LOW);
      digitalWrite(Data5, LOW);
      digitalWrite(Data6, LOW);
      digitalWrite(Data7, HIGH);
      break;
    }
  }
}

void initFirmata()
{
  // Uncomment to save a couple of seconds by disabling the startup blink sequence.
  Firmata.setFirmwareVersion(FIRMATA_FIRMWARE_MAJOR_VERSION, FIRMATA_FIRMWARE_MINOR_VERSION);
  Firmata.attach(STRING_DATA, stringCallback);
  Firmata.disableBlinkVersion();
  Firmata.begin(57600);
}


void setup() {

  initLEDarray();
  initBlinkLEDarray();
  pinMode(13, OUTPUT);
  digitalWrite(13, LOW);
  pinMode(AnalRead, OUTPUT);
  digitalWrite(AnalRead, HIGH);
  pinMode(AnalConv, OUTPUT);
  digitalWrite(AnalConv, HIGH);
  pinMode(LEDwrite, OUTPUT);
  digitalWrite(LEDwrite, HIGH);
  pinMode(buttread, OUTPUT);
  digitalWrite(buttread, HIGH);
  pinMode(Display, OUTPUT);
  digitalWrite(Display, HIGH);
  pinMode(W0, OUTPUT);
  pinMode(W1, OUTPUT);
  pinMode(W2, OUTPUT);
  pinMode(W3, OUTPUT);

  //turn off all lamps
  
  WriteData();
  digitalWrite(Data0, LOW);
  digitalWrite(Data1, LOW);
  digitalWrite(Data2, LOW);
  digitalWrite(Data3, LOW);
  digitalWrite(Data4, LOW);
  digitalWrite(Data5, LOW);
  digitalWrite(Data6, LOW);
  digitalWrite(Data7, LOW);

  
  for(int number =0;number<=11; number ++)
    {
      DecoderOut(number);
    }

  //set initial analog values in array
  ReadData();
  for(int pot = 0; pot < 15; pot++)
  {
      byte currentPotValue = AnalogIn(pot);
      AnalogPreviousValues[pot]=currentPotValue;
  }
  initFirmata();
  delay(10);
  //READY FOR KEYBOARD
  keypad.addEventListener(keypadEvent);
}

void loop() {
  WriteData();
    while(Firmata.available()) {
    Firmata.processInput();
  }
  readAnalogValues();
  delay(50);
  keypad.getKeys();
  //serial.update();
  //delay(10);
  BlinkCount ++;
  if(BlinkCount >6)
  {
    blinkLEDs();
    BlinkCount=0;
    if(BlinkStatus == 0){BlinkStatus = 1;}
    else{BlinkStatus=0;}
  }
  
}

void ReadData(){
  pinMode(Data0, INPUT_PULLUP);
  pinMode(Data1, INPUT_PULLUP);
  pinMode(Data2, INPUT_PULLUP);
  pinMode(Data3, INPUT_PULLUP);
  pinMode(Data4, INPUT_PULLUP);
  pinMode(Data5, INPUT_PULLUP);
  pinMode(Data6, INPUT_PULLUP);
  pinMode(Data7, INPUT_PULLUP);
  }

void WriteData(){
  pinMode(Data0, OUTPUT);
  pinMode(Data1, OUTPUT);
  pinMode(Data2, OUTPUT);
  pinMode(Data3, OUTPUT);
  pinMode(Data4, OUTPUT);
  pinMode(Data5, OUTPUT);
  pinMode(Data6, OUTPUT);
  pinMode(Data7, OUTPUT);
  }
void DecoderOut(byte number)
{
  for(int i =0;i<4; i ++)
    {

        digitalWrite(DecoderPins[i],BCD[number][i]);
    }
      delay(2);
      digitalWrite(LEDwrite, LOW);
      delay(2);
      digitalWrite(LEDwrite, HIGH);
    
}
void SelectLedRow(byte number)
{
  for(int i =0;i<=4; i ++)
    {
      if (bitRead(number, 1)==1){
        digitalWrite(DecoderPins[i],HIGH);
      }else{
        digitalWrite(DecoderPins[i],LOW);
      }
    }
}
void setLight(int pin, byte val) {
  byte arrayElem = int((pin)/BITSB);               // which element of the ledArray is pin in
  byte byteElem  = (pin - (arrayElem * BITSB));  // and which bit in that byte is the pin
  //LEDArray[arrayElem] |= (val << byteElem);          // zero vals require a two-step process, 
  //if(val == 0) {                                     // first we set them to a one and then
  //  ledArray[arrayElem] ^= (1 << byteElem);          // toggle them
  //} 
  byte temp1 = LEDArray[arrayElem];
  bitWrite(temp1,byteElem,val);
  LEDArray[arrayElem] = temp1;
}
void blinkLEDs()
{
  for(int i = 0; i < LedDATABITS; i++) {
    if(BlinkLEDArray[i] == 1) {
      if(BlinkStatus == 1){LEDArray[i]=0;}
      else{LEDArray[i]=1;}
      int LEDSelRow = 0;
      LEDSelRow = i/8; //find row number - this rounds automatically
      //SelectLedRow(LEDSelRow);
      int LedSelCol=0;
      LedSelCol= (i % 8); //use MOD to find bit position
      digitalWrite(buttread, HIGH);
      WriteData();
      for(int i = 0; i < 8; i++) {
        digitalWrite(rowPins[i] ,LEDArray[(LEDSelRow*8)+i]);
      }
      delay(1);
      DecoderOut(LEDSelRow);
      
    }
  }
}
void readAnalogValues()
{
  int AnalogCurrentValues [14];
  ReadData();
      for(int pot = 0; pot < 15; pot++)
      {
        //int area = AnalogIn(pot);
        //if new value <> old value, send itto serial
        byte currentPotValue = AnalogIn(pot);
        int diff = abs(currentPotValue - AnalogPreviousValues[pot]);
        //need high res for t-bar so don't care about jitter
        if((pot == 2) && (diff >0)) {
          AnalogPreviousValues[pot]=currentPotValue;
          String action = "Pot";
          String echoMsg = action+pot+','+currentPotValue;
          Firmata.sendString(echoMsg.c_str());
        }
        if((pot != 2) && (diff > 1))
        {
          AnalogPreviousValues[pot]=currentPotValue;
          String action = "Pot";
          String echoMsg = action+pot+','+currentPotValue;
          Firmata.sendString(echoMsg.c_str());
        }
      }
}
byte AnalogIn(int number)
{
  for(int i =0;i<4; i ++)
    {
        digitalWrite(DecoderPins[i],BCD[number][i]);
    }
    delay(1);
    digitalWrite(AnalConv, LOW);
    delay(1);
    digitalWrite(AnalConv, HIGH);
    delay(1);
    digitalWrite(AnalRead, LOW);
    //read all 8 bits and write value to array of the pot number
    byte inByte = 0;
    for (int r=0; r<8; r++) 
    {
          bitWrite(inByte, r, digitalRead(rowPins[r])); 
    }
    digitalWrite(AnalRead, HIGH);
      //return value as int
      return inByte;
}