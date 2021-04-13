//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#property strict

const int NO_POSITION = 0;
const int LONG_POSITION = 1;
const int SHORT_POSITION = 2;

double smaXX;
double smaShort;
int playDirection = 0;

int orderID;

int positions[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
double positionLevels[10] = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0};
int nextPositionIndex = 0;
double lastPositionLevel = 0.;
double averagePositionLevel = 0.0;

int MAX_SLIPPAGE=100;


extern int smaPeriod = 33;
extern int smaShortPeriod = 1;
extern double LOTS = 1.0;
extern double piramidInterval = 25.0;
extern int maxPositionsInPiramid = 5;
extern double smaMargin = 5.0;
extern bool dynamicStopLossOn = true;
extern bool isLogginOn = true;
extern int MAType = 0;

int magicNumber = 1;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   smaXX = iMA(Symbol(), PERIOD_H1, smaPeriod, 0, MAType, PRICE_CLOSE, 0);
   smaShort = iMA(Symbol(), PERIOD_H1, smaShortPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   comment();

//   if(playDirection == 1 && smaShort < smaXX) {
//      logHandler("==TOUCH SMAXX==");
//      handleTouchSMAXX();
//   } else if(playDirection == -1 && smaShort > smaXX) {
//      logHandler("==TOUCH SMAXX==");
//      handleTouchSMAXX();
   if(playDirection != 0  && MathAbs(smaShort-smaXX) < smaMargin) {
      logHandler("==TOUCH SMAXX==");
      handleTouchSMAXX();
   } else if(playDirection != 1 && smaShort > smaXX + smaMargin) {
      logHandler("==EnterLongState==");
      handleEnterLongState();
   } else if(playDirection != -1 && smaShort < smaXX - smaMargin) {
      logHandler("==EnterShortState==");
      handleEnterShortState();
   } else if(playDirection == 1) {
      logHandler("==continueLong==");
      continueLongState();
   } else if(playDirection == -1) {
      logHandler("==continueShort==");
      continueShortState();
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleTouchSMAXX() {
   if(playDirection == 1) {
      closeAllLongOrders();
   } else {
      closeAllShortOrders();
   }
   playDirection = 0;
}


void handleEnterLongState() {

   closeAllShortOrders();

//close all positions
//clear the array
//reset position index

   playDirection = 1;
   openLongPosition(nextPositionIndex);
}


void handleEnterShortState() {

   closeAllLongOrders();

   playDirection = -1;
   openShortPosition(nextPositionIndex);

}


void continueLongState() {

   if((lastPositionLevel + piramidInterval) <= smaShort && (maxPositionsInPiramid > nextPositionIndex)) {
      openLongPosition(nextPositionIndex);
   } else {
      checkDynamicStopLoss();
   }
}


void continueShortState() {

   if((lastPositionLevel - piramidInterval) >= smaShort && (maxPositionsInPiramid > nextPositionIndex)) {
      openShortPosition(nextPositionIndex);
   } else {
      checkDynamicStopLoss();
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkDynamicStopLoss() {
   if(dynamicStopLossOn && nextPositionIndex > 4) {
      if(playDirection == 1 && smaShort < averagePositionLevel) {
         closeAllLongOrders(averagePositionLevel);
         Print("==Dynamic Stop Loss activated==");
      } else if(playDirection == -1 && smaShort > averagePositionLevel) {
         closeAllShortOrders(averagePositionLevel);
         Print("==Dynamic Stop Loss activated==");
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openLongPosition(int index) {
   int returnedOrderID = OrderSend(Symbol(), OP_BUY, LOTS, Ask, MAX_SLIPPAGE, Ask-1000.0, 0, NULL, magicNumber, 0, Green);
//   lastPositionLevel=Ask;
   
   if (returnedOrderID==0) {
      Print("=============Last Error: ", GetLastError());
      logMessage("===Position selected by Magic Number===");
      bool selectedOrder = OrderSelect(magicNumber, SELECT_BY_POS);
      orderID = OrderTicket();
   } else {
      orderID = returnedOrderID;
   };

   if(OrderSelect(orderID, SELECT_BY_TICKET)) {

      positions[index] = orderID;
      positionLevels[index] = OrderOpenPrice();
      lastPositionLevel = OrderOpenPrice();
      nextPositionIndex++;
      averagePositionLevel = getAverageLevel();

      logMessage("Long position opened: " + orderID + ", Price: " + OrderOpenPrice());
   } else {
         logMessage("Problem with order selection");
   }

   magicNumber++;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openShortPosition(int index) {
   int returnedOrderID = OrderSend(Symbol(), OP_SELL, LOTS, Bid, MAX_SLIPPAGE, Bid+1000.0, 0, NULL, magicNumber, 0, Red);
//   lastPositionLevel=Bid;

   if (returnedOrderID==0) {
      Print("===OrderID = 0 ===== Last Error: ", GetLastError());

      bool selectedOrder = OrderSelect(magicNumber, SELECT_BY_POS);
      orderID = OrderTicket();
   } else {
      orderID = returnedOrderID;
   }


   if(OrderSelect(orderID, SELECT_BY_TICKET) == true) {

      positions[index] = orderID;
      positionLevels[index] = OrderOpenPrice();
      lastPositionLevel = OrderOpenPrice();
      nextPositionIndex++;
      averagePositionLevel = getAverageLevel();

      logMessage("Short position opened: " + orderID + " Price: " + OrderOpenPrice());
   } else {
      logMessage("Problem with order selection");
   }
   magicNumber++;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllLongOrders(double setNewLastPositionLevel = 0.0) {
   closeAllOrders(Bid, Green);
   lastPositionLevel = setNewLastPositionLevel;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllShortOrders(double setNewLastPositionLevel = 0.0) {
   closeAllOrders(Ask, Red);
   lastPositionLevel = setNewLastPositionLevel;
}

void closeAllOrders(double priceBidAsk, color arrowColor) {

   for(int i = 0; i < nextPositionIndex; i++) {
      OrderClose(positions[i], LOTS, priceBidAsk, MAX_SLIPPAGE, arrowColor);
      positions[i] = NO_POSITION;
      positionLevels[i] = 0.0;
   }

   nextPositionIndex = 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color getColorForCurrentMarketSide(int direction) {
   if(direction == 1) {
      return Green;
   } else {
      return Red;
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getClosingPriceForCurrentMarketSide(int direction) {
   if(direction == 1) {
      return Bid;
   } else {
      return Ask;
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getAverageLevel() {
   if(nextPositionIndex>0) {
      double sum = 0.0;

      for(int i = 0; i < nextPositionIndex; i++) {
         sum += positionLevels[i];
      }

      return sum/nextPositionIndex;
   } else return 0.0;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void comment() {
   Comment("smaXX: " + (string)smaXX + "\n"
           + "playDirection?: " + (string)playDirection + "\n"
           + "smaShort: " + (string)smaShort + "\n"
           + "position0: " + (string)positions[0] + "/  "
           + "position1: " + (string)positions[1] + "/  "
           + "position2: " + (string)positions[2] + "/  "
           + "position3: " + (string)positions[3] + "/  "
           + "position4: " + (string)positions[4] + "\n"
           + "lastPositionLevel: " + (string)lastPositionLevel + "\n"
           + "nextPositionIndex: " + (string)nextPositionIndex + "\n"
           + "lastPositionLevel + piramidInterval: " + (string)(lastPositionLevel + piramidInterval) + "\n"
           + "lastPositionLevel - piramidInterval: " + (string)(lastPositionLevel - piramidInterval) + "\n"
           + "averageLevel: " + (string)averagePositionLevel + "\n"
          );
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void logHandler(string handler) {
   if(isLogginOn) {
      printf("Current Handler: %s", handler);
   }
}

void logMessage(string message){
   if(isLogginOn) {
      printf(message);
   }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
