//+------------------------------------------------------------------+
//|                                           Harriet Hedging EA.mq5 |
//|                                                       Joy D Moyo |
//|                                               www.latvianfts.com |
//+------------------------------------------------------------------+
#property copyright "Joy D Moyo"
#property link      "www.latvianfts.com"
#property version   "1.00"
#include<Trade\Trade.mqh>

CTrade *Trade;
CPositionInfo PositionInfo;

input group "GENERAL INPUTS"
input int EAMagic = 767876;
input int MaxSlippage = 1;
input string SymbolTraded = "EURUSD";
input ENUM_TIMEFRAMES HTPeriod = PERIOD_H1;
input ENUM_TIMEFRAMES LTPeriod = PERIOD_M5;
input bool ShowObjects = true;

input group "BAR PROPERTY INPUTS"
input int HTMinDistance = 5;
input int LTMinDistance = 2;

input group "TRADE MANAGEMENT INPUTS"
input int TakeProfit = 30;
input int StopLoss = 5;
input int WhenToTrail = 10;

input group "RISK INPUTS"
input double BalanceIncrease = 3000;
input double VolumeIncrease = 0.01;

double HTBarHigh[],HTBarLow[],HTBarClose[],HTBarOpen[],LTBarHigh[],LTBarLow[],LTBarClose[],LTBarOpen[],HTMinDistancePoints,LTMinDistancePoints,MyPoint,STP,TKP,WhenToTrailPrice;
int HTOldNumBars = 0,LTOldNumBars = 0,MyDigits;
bool Bought = false, Sold = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrDodgerBlue);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,clrDodgerBlue);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,clrWhite);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,clrWhite);
   ChartSetInteger(0,CHART_COLOR_STOP_LEVEL,clrGold);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,false);

   ArraySetAsSeries(HTBarClose,true);
   ArraySetAsSeries(HTBarHigh,true);
   ArraySetAsSeries(HTBarLow,true);
   ArraySetAsSeries(HTBarOpen,true);
   ArraySetAsSeries(LTBarClose,true);
   ArraySetAsSeries(LTBarHigh,true);
   ArraySetAsSeries(LTBarLow,true);
   ArraySetAsSeries(LTBarOpen,true);


   MyPoint = SymbolInfoDouble(SymbolTraded,SYMBOL_POINT);
   MyDigits = (int)SymbolInfoInteger(SymbolTraded,SYMBOL_DIGITS);
   HTMinDistancePoints = HTMinDistance*10*MyPoint;
   LTMinDistancePoints = LTMinDistance*10*MyPoint;

   Trade = new CTrade;
   ulong MaxSlippagePoints = MaxSlippage*10;
   Trade.SetExpertMagicNumber(EAMagic);
   Trade.SetDeviationInPoints(MaxSlippagePoints);
   STP = StopLoss*10*MyPoint;
   TKP = TakeProfit*10*MyPoint;
   WhenToTrailPrice = WhenToTrail*10*MyPoint;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {


  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CopyHTBars();
   if(!NewBarPresent(LTPeriod,LTOldNumBars))
      return;
   CopyLTBars();
   Buy();
   Sell();

   if(NumOfBuy()==0)
      Bought = false;
   if(NumOfSell()==0)
      Sold = false;

   if(BuySignal())
      DrawObjects("Buy",LTPeriod,clrLimeGreen);
   if(SellSignal())
      DrawObjects("Sell",LTPeriod,clrYellow);

   BuyTrailingTP();
   SellTrailingTP();
   BuyTrailingSL();
   SellTrailingSL();
  }
//+------------------------------------------------------------------+
bool NewBarPresent(const ENUM_TIMEFRAMES TradedPeriod, int& OldNumBars)
  {
   int bars = Bars(SymbolTraded,TradedPeriod);
   if(OldNumBars!=bars)
     {
      OldNumBars = bars;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CopyHTBars()
  {
   if(!NewBarPresent(HTPeriod,HTOldNumBars))
      return;
   CopyHigh(SymbolTraded,HTPeriod,1,3,HTBarHigh);
   CopyLow(SymbolTraded,HTPeriod,1,3,HTBarLow);
   CopyClose(SymbolTraded,HTPeriod,1,3,HTBarClose);
   CopyOpen(SymbolTraded,HTPeriod,1,3,HTBarOpen);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CopyLTBars()
  {
   CopyHigh(SymbolTraded,LTPeriod,1,3,LTBarHigh);
   CopyLow(SymbolTraded,LTPeriod,1,3,LTBarLow);
   CopyClose(SymbolTraded,LTPeriod,1,3,LTBarClose);
   CopyOpen(SymbolTraded,LTPeriod,1,3,LTBarOpen);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NumOfBuy()
  {
   int Num = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_BUY)
         continue;
      Num++;
     }
   return Num;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int NumOfSell()
  {
   int Num = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_SELL)
         continue;
      Num++;
     }
   return Num;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LowerHigh(const double& CurrHigh[],const double& PrevHigh[],const double& PriceOpen[],const double& PriceClose[],const double MinDistance)
  {
   if(CurrHigh[0]<PrevHigh[1]&&PriceOpen[0]>PriceClose[0]&&PrevHigh[1]-CurrHigh[0]>MinDistance)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HigherLow(const double& CurrLow[],const double& PrevLow[],const double& PriceOpen[],const double& PriceClose[],const double MinDistance)
  {
   if(CurrLow[0]>PrevLow[1]&&PriceOpen[0]<PriceClose[0]&&CurrLow[0]-PrevLow[1]>MinDistance)
      return true;
   return false;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal()
  {
   if(HigherLow(HTBarLow,HTBarLow,HTBarOpen,HTBarClose,HTMinDistancePoints)&&HigherLow(LTBarLow,LTBarLow,LTBarOpen,LTBarClose,LTMinDistancePoints))
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal()
  {
   if(LowerHigh(HTBarHigh,HTBarHigh,HTBarOpen,HTBarClose,HTMinDistancePoints)&&LowerHigh(LTBarHigh,LTBarHigh,LTBarOpen,LTBarClose,LTMinDistancePoints))
      return true;
   return false;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawObjects(const string Name, const ENUM_TIMEFRAMES PeriodTraded,const color ObjColor)
  {
   if(!ShowObjects)
      return;
   double PriceClose = iClose(SymbolTraded,PeriodTraded,1);
   string ObjName = Name+(string)iTime(SymbolTraded,PeriodTraded,1);
   if(!ObjectCreate(0,ObjName,OBJ_TREND,0,iTime(SymbolTraded,PeriodTraded,1),PriceClose,iTime(SymbolTraded,PeriodTraded,0),PriceClose))
      return;
   else
     {
      ObjectSetInteger(0,ObjName,OBJPROP_COLOR,ObjColor);
      ObjectSetInteger(0,ObjName,OBJPROP_WIDTH,5);
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LotSize()
  {
   double Lot = NormalizeDouble(VolumeIncrease*AccountInfoDouble(ACCOUNT_BALANCE)/BalanceIncrease,2);
   if(Lot>SymbolInfoDouble(SymbolTraded,SYMBOL_VOLUME_MAX))
      Lot=SymbolInfoDouble(SymbolTraded,SYMBOL_VOLUME_MAX);
   if(Lot<SymbolInfoDouble(SymbolTraded,SYMBOL_VOLUME_MIN))
      Lot = SymbolInfoDouble(SymbolTraded,SYMBOL_VOLUME_MIN);
   return Lot;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Buy()
  {
   if(!BuySignal()||Bought)
      return;
   double LotUsed = LotSize();
   double ASK = SymbolInfoDouble(SymbolTraded,SYMBOL_ASK);
   if(!Trade.Buy(LotUsed,SymbolTraded,ASK,0,ASK+TKP,"Buy"))
      Print("Failed to Buy : ",GetLastError());
   else
     {
      Bought = true;
      Sold = false;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Sell()
  {
   if(!SellSignal()||Sold)
      return;
   double LotUsed = LotSize();
   double BID = SymbolInfoDouble(SymbolTraded,SYMBOL_BID);
   if(!Trade.Sell(LotUsed,SymbolTraded,BID,0,BID-TKP,"Sell"))
      Print("Failed to Sell : ",GetLastError());
   else
     {
      Bought = false;
      Sold = true;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AvgBuyPrice()
  {
   double tot = 0,avg = 0;
   int Num = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_BUY)
         continue;
      Num++;
      tot += PositionInfo.PriceOpen();
     }
   avg = tot/Num;
   return NormalizeDouble(avg,MyDigits);
  }
//+------------------------------------------------------------------+
double AvgSellPrice()
  {
   double tot = 0,avg = 0;
   int Num = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_SELL)
         continue;
      Num++;
      tot += PositionInfo.PriceOpen();
     }
   avg = tot/Num;
   return NormalizeDouble(avg,MyDigits);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BuyTrailingTP()
  {
   if(NumOfBuy()<2)
      return;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_BUY)
         continue;

      ulong MyTicket = PositionInfo.Ticket();
      double CurrentTP = PositionInfo.TakeProfit(),CurrentSL = PositionInfo.StopLoss(),CurrentPrice = PositionInfo.PriceCurrent(),TP = AvgBuyPrice();

      if(CurrentTP!=0)
         if(TP==CurrentTP||TP<=CurrentPrice)
            continue;
      if(!Trade.PositionModify(MyTicket,0,TP))
         Alert("Error Modifying Position [%d]",GetLastError());
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SellTrailingTP()
  {
   if(NumOfSell()<2)
      return;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_SELL)
         continue;

      ulong MyTicket = PositionInfo.Ticket();
      double CurrentTP = PositionInfo.TakeProfit(),CurrentSL = PositionInfo.StopLoss(),CurrentPrice = PositionInfo.PriceCurrent(),TP = AvgSellPrice();

      if(CurrentTP!=0)
         if(TP==CurrentTP||TP>=CurrentPrice)
            continue;
      if(!Trade.PositionModify(MyTicket,0,TP))
         Alert("Error Modifying Position [%d]",GetLastError());
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BuyTrailingSL()
  {
   if(NumOfBuy()!=1)
      return;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_BUY)
         continue;
      double CurrentSL = PositionInfo.StopLoss(),OpenPrice = PositionInfo.PriceOpen(),PositionTP = PositionInfo.TakeProfit(),CurrentPrice = PositionInfo.PriceCurrent();
      double PriceLow = iLow(SymbolTraded,LTPeriod,1);
      double BuyTrailPrice = NormalizeDouble(OpenPrice + WhenToTrailPrice,MyDigits);
      if(CurrentPrice<BuyTrailPrice)
         continue;
      double NewSl = PriceLow;
      if(CurrentSL!=0)
         if(NewSl<=CurrentSL||NewSl>=CurrentPrice)
            continue;
      if(!Trade.PositionModify(PositionInfo.Ticket(),NewSl,PositionTP))
         Print("Position Modifying Failed due to error code: ", GetLastError());
     }
  }
//+------------------------------------------------------------------+

void SellTrailingSL()
  {
   if(NumOfSell()!=1)
      return;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(!PositionInfo.SelectByIndex(i))
         continue;
      if(PositionInfo.Magic()!=EAMagic)
         continue;
      if(PositionInfo.Symbol()!=SymbolTraded)
         continue;
      if(PositionInfo.PositionType()!=POSITION_TYPE_SELL)
         continue;
      double CurrentSL = PositionInfo.StopLoss(),OpenPrice = PositionInfo.PriceOpen(),PositionTP = PositionInfo.TakeProfit(),CurrentPrice = PositionInfo.PriceCurrent();
      double PriceHigh = iHigh(SymbolTraded,LTPeriod,1);
      double SellTrailPrice = NormalizeDouble(OpenPrice - WhenToTrailPrice,MyDigits);
      if(CurrentPrice>SellTrailPrice)
         continue;
      double NewSl = PriceHigh;
      if(CurrentSL!=0)
         if(NewSl>=CurrentSL||NewSl<=CurrentPrice)
            continue;
      if(!Trade.PositionModify(PositionInfo.Ticket(),NewSl,PositionTP))
         Print("Position Modifying Failed due to error code: ", GetLastError());
     }
  }