//
// EA Studio Expert Advisor
//
// Created with: Expert Advisor Studio
// Website: https://studio.eatradingacademy.com/
//
// Copyright 2024, Forex Software Ltd.
//
// Risk Disclosure
//
// Futures and forex trading contains substantial risk and is not for every investor.
// An investor could potentially lose all or more than the initial investment.
// Risk capital is money that can be lost without jeopardizing ones financial security or life style.
// Only risk capital should be used for trading and only those with sufficient risk capital should consider trading.

#property copyright "Forex Software Ltd."
#property version   "6.0"
#property strict

static input string _Properties_ = "------"; // --- Expert Properties ---
static input int    Magic_Number = 240402530; // Magic number
static input double Entry_Amount =     0.10; // Entry lots
       input int    Stop_Loss    =     4186; // Stop Loss   (pips)
       input int    Take_Profit  =     8184; // Take Profit (pips)

static input string ___0______   = "------"; // --- Entry Time ---
       input int    Ind0Param0   =        1; // From hour
       input int    Ind0Param1   =        0; // From minute
       input int    Ind0Param2   =       23; // Until hour
       input int    Ind0Param3   =        0; // Until minute

static input string ___1______   = "------"; // --- Accelerator Oscillator ---
       input double Ind1Param0   =   0.0000; // Level

static input string ___2______   = "------"; // --- Accelerator Oscillator ---
       input double Ind2Param0   =   0.0000; // Level

static input string ___3______   = "------"; // --- DeMarker ---
       input int    Ind3Param0   =        1; // Period
       input double Ind3Param1   =     0.00; // Level

static input string ___4______   = "------"; // --- Pin Bar ---
       input int    Ind4Param0   =        7; // Max body part %
       input int    Ind4Param1   =       36; // Min wick part %

// "Entry protections" prevents new entry if a protection is activated
static input string Entry_prot__ = "------"; // --- Entry Protections ---
static input int    Max_Spread   =        0; // Max spread (points)
static input int    Max_OpenPos  =        0; // Max open positions
static input double Max_OpenLots =        0; // Max open lots

// "Account protections" stops the expert if a protection is activated
static input string Account_prot = "------"; // --- Account Protections ---
static input int    MaxDailyLoss =        0; // Maximum daily loss (currency)
static input int    Min_Equity   =        0; // Minimum equity (currency)
static input int    Max_Equity   =        0; // Maximum equity (currency)

static input string _NewsFilter_ = "------"; // --- News Filter ---
enum NewsFilterPriority
  {
   NewsFilter_Disabled,     // News filter disabled
   NewsFilter_HighOnly,     // High news filter
   NewsFilter_HighAndMedium // Medium and High news filter
  };
static input NewsFilterPriority News_Priority = NewsFilter_Disabled;       // News priority
static input string News_Currencies   = "USD,EUR,JPY,GBP,CAD,AUD,CHF,NZD"; // News currencies
static input int    News_BeforeMedium =  2; // Before Medium news (minutes)
static input int    News_AfterMedium  =  2; // After Medium news (minutes)
static input int    News_BeforeHigh   =  2; // Before High news (minutes)
static input int    News_AfterHigh    =  5; // After High news (minutes)
static input int    News_ViewCount    = 10; // News records to show

static input string __Stats_____ = "------"; // --- Stats ---
static input bool   Pos_Stat     =     true; // Position stats
static input bool   Robot_Stats  =     true; // Robot stats

#define TRADE_RETRY_COUNT   4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT            -1

string robotTagline  = "An Expert Advisor from Expert Advisor Studio";

// Session time is set in seconds from 00:00
int  sessionSundayOpen          =     0; // 00:00
int  sessionSundayClose         = 86400; // 24:00
int  sessionMondayThursdayOpen  =     0; // 00:00
int  sessionMondayThursdayClose = 86400; // 24:00
int  sessionFridayOpen          =     0; // 00:00
int  sessionFridayClose         = 86400; // 24:00
bool sessionIgnoreSunday        = true;
bool sessionCloseAtSessionClose = false;
bool sessionCloseAtFridayClose  = false;

const double sigma = 0.000001;

int    posType       = OP_FLAT;
int    posTicket     = 0;
double posLots       = 0;
double posStopLoss   = 0;
double posTakeProfit = 0;
double posProfit     = 0;
double posPriceOpen  = 0;
double posPriceCurr  = 0;

datetime lastStatsUpdate = 0;
datetime barTime;
double   pip;
double   stopLevel;
bool     isTrailingStop=false;
bool     setProtectionSeparately = false;

int    maxRectangles = 0;
int    maxLabels     = 0;
int    posStatCount  = 0;
double posStatLots   = 0;

string accountProtectionMessage = "";
string entryProtectionMessage   = "";

struct NewsRecord
  {
   datetime time;
   string   priority;
   string   currency;
   string   title;
  };

NewsRecord newsRecords[];
string   newsCurrencies[];
datetime lastNewsUpdate = 0;
string   loadNewsError  = "";
bool     isNewsFeedOk   = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   barTime         = Time[0];
   stopLevel       = MarketInfo(_Symbol, MODE_STOPLEVEL);
   pip             = GetPipValue();
   isTrailingStop  = isTrailingStop && Stop_Loss > 0;
   lastStatsUpdate = 0;

   Comment("");
   UpdatePosition();

   ParseNewsCurrenciesText();
   lastNewsUpdate = TimeCurrent();
   if(!MQLInfoInteger(MQL_TESTER))
      LoadNews();

   DeleteObjects();

   OnTick();
   ChartRedraw(0);

   return ValidateInit();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteObjects();

   if(accountProtectionMessage != "")
      Comment(accountProtectionMessage);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteObjects(void)
  {
   if(ObjectFind(0, "Stats_background") == 0)
      ObjectDelete(0, "Stats_background");
   maxLabels = MathMax(maxLabels, 35);
   for(int i = 0; i < maxLabels; i += 1)
     {
      const string objName = "label" + IntegerToString(i);
      if(ObjectFind(0, objName) == 0)
         ObjectDelete(0, objName);
     }
   maxRectangles = 0;
   maxLabels     = 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      CheckAccountProtection();
      const datetime time = TimeCurrent();
      if(time > lastStatsUpdate + 3)
        {
         lastStatsUpdate = time;
         if(Max_OpenPos || Max_OpenLots)
            SetPosStats();

         UpdateStats();
        }

      if(time > lastNewsUpdate + 6*60*60 || !isNewsFeedOk)
        {
         lastNewsUpdate = time;
         LoadNews();
        }
     }

   const datetime time = Time(0);
   if(time > barTime)
     {
      barTime = time;
      OnBar();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar(void)
  {
   UpdatePosition();

   if(posType != OP_FLAT && IsForceSessionClose())
     {
      ClosePosition();
      return;
     }

   if(IsOutOfSession())
      return;

   if(posType != OP_FLAT)
     {
      ManageClose();
      UpdatePosition();
     }

   if(posType != OP_FLAT && isTrailingStop)
     {
      double trailingStop = GetTrailingStopPrice();
      ManageTrailingStop(trailingStop);
      UpdatePosition();
     }

   int entrySignal = GetEntrySignal();

   if(posType == OP_FLAT && entrySignal != OP_FLAT)
     {
      OpenPosition(entrySignal);
      UpdatePosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePosition(void)
  {
   posType       = OP_FLAT;
   posTicket     = 0;
   posLots       = 0;
   posProfit     = 0;
   posStopLoss   = 0;
   posTakeProfit = 0;
   posPriceOpen  = 0;
   posPriceCurr  = 0;

   for(int pos = OrdersTotal() - 1; pos >= 0; pos -= 1)
     {
      if(OrderSelect(pos, SELECT_BY_POS) &&
         OrderSymbol()      == _Symbol   &&
         OrderMagicNumber() == Magic_Number)
        {
         posType       = OrderType();
         posTicket     = OrderTicket();
         posLots       = OrderLots();
         posProfit     = OrderProfit();
         posStopLoss   = OrderStopLoss();
         posTakeProfit = OrderTakeProfit();
         posPriceOpen  = NormalizeDouble(OrderOpenPrice(),  _Digits);
         posPriceCurr  = NormalizeDouble(OrderClosePrice(), _Digits);
         break;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetEntrySignal(void)
  {
   // Entry Time (1, 0, 23, 0)

   int fromTime0  = Ind0Param0 * 3600 + Ind0Param1 * 60;
   int untilTime0 = Ind0Param2 * 3600 + Ind0Param3 * 60;

   MqlDateTime mqlTime0;
   TimeToStruct(Time(0), mqlTime0);
   int barMinutes0 = mqlTime0.hour * 3600 + mqlTime0.min * 60;

   bool isOnTime0 = fromTime0 < untilTime0
      ? barMinutes0 >= fromTime0 && barMinutes0 <= untilTime0
      : barMinutes0 >= fromTime0 || barMinutes0 <= untilTime0;

   bool ind0long  = isOnTime0;
   bool ind0short = isOnTime0;


   // Accelerator Oscillator, Level: 0.0000
   double ind1val1  = iAC(NULL, 0, 1);
   double ind1val2  = iAC(NULL, 0, 2);
   bool   ind1long  = ind1val1 < Ind1Param0 - sigma && ind1val2 > Ind1Param0 + sigma;
   bool   ind1short = ind1val1 > -Ind1Param0 + sigma && ind1val2 < -Ind1Param0 - sigma;

   // Accelerator Oscillator
   double ind2val1  = iAC(NULL, 0, 1);
   double ind2val2  = iAC(NULL, 0, 2);
   bool   ind2long  = ind2val1 < ind2val2 - sigma;
   bool   ind2short = ind2val1 > ind2val2 + sigma;

   // DeMarker (1)
   double ind3val1  = iDeMarker(NULL, 0, Ind3Param0, 1);
   double ind3val2  = iDeMarker(NULL, 0, Ind3Param0, 2);
   double ind3val3  = iDeMarker(NULL, 0, Ind3Param0, 3);
   bool   ind3long  = ind3val1 > ind3val2 + sigma && ind3val2 < ind3val3 - sigma;
   bool   ind3short = ind3val1 < ind3val2 - sigma && ind3val2 > ind3val3 + sigma;

   bool canOpenLong  = ind0long && ind1long && ind2long && ind3long;
   bool canOpenShort = ind0short && ind1short && ind2short && ind3short;

   return canOpenLong  && !canOpenShort ? OP_BUY
        : canOpenShort && !canOpenLong  ? OP_SELL
        : OP_FLAT;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageClose(void)
  {
   // Pin Bar (7, 36)

   bool ind4long  = false;
   bool ind4short = false;

   {
      double closeOpen = MathAbs(Close(1) - Open(1));
      bool isPinBar = closeOpen < Ind4Param0 * 0.01 * (High(1) - Low(1));
      bool upWick   = High(1) - MathMax(Close(1), Open(1)) > Ind4Param1 * 0.01 * closeOpen;
      bool downWick = MathMin(Close(1), Open(1)) - Low(1)  > Ind4Param1 * 0.01 * closeOpen;
      bool isBearishPinBar = isPinBar && upWick && !downWick;
      bool isBullishPinBar = isPinBar && downWick && !upWick;

      ind4long  = isBullishPinBar;
      ind4short = isBearishPinBar;
   }

   if((posType == OP_BUY  && ind4long) ||
        (posType == OP_SELL && ind4short) )
      ClosePosition();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(const int command)
  {
   entryProtectionMessage = "";
   const int spread = (int)((Ask() - Bid()) / _Point);
   if(Max_OpenPos  > sigma && posStatCount > Max_OpenPos)
      entryProtectionMessage += StringFormat("Protection: Max open positions: %d, current: %d\n",
                                             Max_OpenPos, posStatCount);
   if(Max_OpenLots > sigma && posStatLots > Max_OpenLots)
      entryProtectionMessage += StringFormat("Protection: Max open lots: %.2f, current: %.2f\n",
                                             Max_OpenLots, posStatLots);
   if(Max_Spread > sigma && spread > Max_Spread)
      entryProtectionMessage += StringFormat("Protection: Max spread: %d, current: %d\n",
                                             Max_Spread, spread);

   const int newsIndex = NewsFilterActive();
   if(newsIndex > -1)
     {
      const NewsRecord newsRecord = newsRecords[newsIndex];
      const datetime timeShift = (datetime) MathRound((TimeLocal() - TimeGMT()) / 3600.0) * 3600;
      const string   priority  = newsRecord.priority == "high" ? "[high]" : "[med]";
      entryProtectionMessage  += StringFormat("News filter: %s %s %s %s\n",
                                              priority,
                                              TimeToString(newsRecord.time + timeShift,
                                                    TIME_DATE | TIME_MINUTES),
                                              newsRecord.currency,
                                              newsRecord.title);
     }

   if(entryProtectionMessage != "")
     {
      entryProtectionMessage = TimeToString(TimeCurrent()) + " " +
                               "Entry order was canceled:\n" +
                               entryProtectionMessage;
      return;
     }

   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      int    ticket     = 0;
      int    lastError  = 0;
      bool   modified   = false;
      string comment    = IntegerToString(Magic_Number);
      color  arrowColor = command == OP_BUY ? clrGreen : clrRed;

      if(IsTradeContextFree())
        {
         const double price      = command == OP_BUY ? Ask() : Bid();
         const double stopLoss   = GetStopLossPrice(command);
         const double takeProfit = GetTakeProfitPrice(command);

         if(setProtectionSeparately)
           {
            // Send an entry order without SL and TP
            ticket = OrderSend(_Symbol, command, Entry_Amount, price, 10, 0, 0, comment, Magic_Number, 0, arrowColor);

            // If the order is successful, modify the position with the corresponding SL and TP
            if(ticket > 0 && (Stop_Loss > 0 || Take_Profit > 0))
               modified = OrderModify(ticket, 0, stopLoss, takeProfit, 0, clrBlue);
           }
         else
           {
            // Send an entry order with SL and TP
            ticket    = OrderSend(_Symbol, command, Entry_Amount, price, 10, stopLoss, takeProfit, comment, Magic_Number, 0, arrowColor);
            lastError = GetLastError();

            // If order fails, check if it is because inability to set SL or TP
            if(ticket <= 0 && lastError == 130)
              {
               // Send an entry order without SL and TP
               ticket = OrderSend(_Symbol, command, Entry_Amount, price, 10, 0, 0, comment, Magic_Number, 0, arrowColor);

               // Try setting SL and TP
               if(ticket > 0 && (Stop_Loss > 0 || Take_Profit > 0))
                  modified = OrderModify(ticket, 0, stopLoss, takeProfit, 0, clrBlue);

               // Mark the expert to set SL and TP with a separate order
               if(ticket > 0 && modified)
                 {
                  setProtectionSeparately = true;
                  Print("Detected ECN type position protection.");
                 }
              }
           }
        }

      if(ticket > 0) break;

      lastError = GetLastError();
      if(lastError != 135 && lastError != 136 && lastError != 137 && lastError != 138)
         break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Open Position retry no: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePosition(void)
  {
   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      bool closed;
      int lastError = 0;

      if(IsTradeContextFree())
        {
         const double price = posType == OP_BUY ? Bid() : Ask();
         closed    = OrderClose(posTicket, posLots, price, 10, clrYellow);
         lastError = GetLastError();
        }

      if(closed) break;
      if(lastError == 4108) break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Close Position retry no: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(void)
  {
   for(int attempt = 0; attempt < TRADE_RETRY_COUNT; attempt++)
     {
      bool modified;
      int lastError = 0;

      if(IsTradeContextFree())
        {
         modified  = OrderModify(posTicket, 0, posStopLoss, posTakeProfit, 0, clrBlue);
         lastError = GetLastError();
        }

      if(modified)
         break;

      if(lastError == 4108) break;

      Sleep(TRADE_RETRY_WAIT);
      Print("Modify Position retry no: " + IntegerToString(attempt + 2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(int command)
  {
   if(Stop_Loss == 0) return 0;

   const double delta    = MathMax(pip * Stop_Loss, _Point * stopLevel);
   const double stopLoss = command == OP_BUY ? Bid() - delta : Ask() + delta;

   return NormalizeDouble(stopLoss, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(int command)
  {
   if(Take_Profit == 0) return 0;

   const double delta      = MathMax(pip * Take_Profit, _Point * stopLevel);
   const double takeProfit = command == OP_BUY ? Bid() + delta : Ask() - delta;

   return NormalizeDouble(takeProfit, _Digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrailingStopPrice(void)
  {
   const double bid = Bid();
   const double ask = Ask();
   const double spread = ask - bid;
   const double stopLevelPoints = _Point * stopLevel;
   const double stopLossPoints  = pip * Stop_Loss;

   if(posType == OP_BUY)
     {
      const double newStopLoss = High(1) - stopLossPoints;
      if(posStopLoss <= newStopLoss - pip)
         return newStopLoss < bid
                 ? newStopLoss >= bid - stopLevelPoints
                    ? bid - stopLevelPoints
                    : newStopLoss
                 : bid;
     }

   if(posType == OP_SELL)
     {
      const double newStopLoss = Low(1) + spread + stopLossPoints;
      if(posStopLoss >= newStopLoss + pip)
         return newStopLoss > ask
                 ? newStopLoss <= ask + stopLevelPoints
                    ? ask + stopLevelPoints
                    : newStopLoss
                 : ask;
     }

   return posStopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(double trailingStop)
  {
   if((posType == OP_BUY  && MathAbs(trailingStop - Bid()) < _Point) ||
      (posType == OP_SELL && MathAbs(trailingStop - Ask()) < _Point))
     {
      ClosePosition();
      return;
     }

   if( MathAbs(trailingStop - posStopLoss) > _Point )
     {
      posStopLoss = NormalizeDouble(trailingStop, _Digits);
      ModifyPosition();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Bid(void)
  {
   return MarketInfo(_Symbol, MODE_BID);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Ask(void)
  {
   return MarketInfo(_Symbol, MODE_ASK);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int bar)
  {
   return Time[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(int bar)
  {
   return Open[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(int bar)
  {
   return High[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(int bar)
  {
   return Low[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(int bar)
  {
   return Close[bar];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipValue()
  {
   return _Digits == 4 || _Digits == 5 ? 0.0001
        : _Digits == 2 || _Digits == 3 ? 0.01
                        : _Digits == 1 ? 0.1 : 1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree(void)
  {
   if(IsTradeAllowed())
      return true;

   const uint startWait = GetTickCount();
   Print("Trade context is busy! Waiting...");

   while(true)
     {
      if(IsStopped())
         return false;

      const uint diff = GetTickCount() - startWait;
      if(diff > 30 * 1000)
        {
         Print("The waiting limit exceeded!");
         return false;
        }

      if(IsTradeAllowed())
        {
         RefreshRates();
         return true;
        }

      Sleep(TRADE_RETRY_WAIT);
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession(void)
  {
   const int dayOfWeek    = DayOfWeek();
   const int periodStart  = int(Time(0) % 86400);
   const int periodLength = PeriodSeconds(_Period);
   const int periodFix    = periodStart + (sessionCloseAtSessionClose ? periodLength : 0);
   const int friBarFix    = periodStart + (sessionCloseAtFridayClose ||
                                           sessionCloseAtSessionClose ? periodLength : 0);

   return dayOfWeek == 0 && sessionIgnoreSunday ? true
        : dayOfWeek == 0 ? periodStart < sessionSundayOpen ||
                           periodFix   > sessionSundayClose
        : dayOfWeek  < 5 ? periodStart < sessionMondayThursdayOpen ||
                           periodFix   > sessionMondayThursdayClose
                         : periodStart < sessionFridayOpen ||
                           friBarFix > sessionFridayClose;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose(void)
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose)
      return false;

   const int dayOfWeek = DayOfWeek();
   const int periodEnd = int(Time(0) % 86400) + PeriodSeconds(_Period);

   return dayOfWeek == 0 && sessionCloseAtSessionClose ? periodEnd > sessionSundayClose
        : dayOfWeek  < 5 && sessionCloseAtSessionClose ? periodEnd > sessionMondayThursdayClose
        : dayOfWeek == 5 ? periodEnd > sessionFridayClose : false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAccountProtection(void)
  {
   const double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(Min_Equity > sigma && accountEquity < Min_Equity)
     {
      const string equityTxt = DoubleToString(accountEquity, 2);
      const string message = "Minimum equity protection activated. Equity: " + equityTxt;
      ActivateProtection(message);
      return;
     }

   if(Max_Equity > sigma && accountEquity >= Max_Equity)
     {
      const string equityTxt = DoubleToString(accountEquity, 2);
      const string message = "Maximum equity protection activated. Equity: " + equityTxt;
      ActivateProtection(message);
      return;
     }

   if(MaxDailyLoss > sigma)
     {
      const double dailyProfit = GetLastDaysProfit(1, -1);
      if(dailyProfit < 0 && MathAbs(dailyProfit) >= MaxDailyLoss)
        {
         const string dailyProfitTxt = DoubleToString(MathAbs(dailyProfit), 2);
         const string message = "Maximum daily loss protection activate! Daily loss: " + dailyProfitTxt;
         ActivateProtection(message);
         return;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLastDaysProfit(int days, int magic)
  {
   const datetime t0 = TimeCurrent();
   const datetime t1 = t0 - 60*60*24;

   double lastProfit = 0;

   const int totalOrders = OrdersTotal();
   for(int i = 0; i < totalOrders; i+=1)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderCloseTime() > t1 && OrderCloseTime() <= t0) ||
            OrderCloseTime() == 0)
           {
            const int ordType = OrderType();
            if(ordType != OP_BUY && ordType != OP_SELL) continue;
            if(magic > 0 && (OrderMagicNumber() != Magic_Number ||
                             OrderSymbol() != _Symbol)) continue;

            lastProfit += OrderProfit() + OrderSwap() + OrderCommission();
           }
        }
     }

   return lastProfit;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ActivateProtection(string message)
  {
   if(posType == OP_BUY || posType == OP_SELL)
      ClosePosition();

   DeleteObjects();

   accountProtectionMessage  = StringFormat("\n%s\nMagic number: %d\n", robotTagline, Magic_Number);
   accountProtectionMessage += message + "\n";
   accountProtectionMessage += "Current position closed. ";
   accountProtectionMessage += "Expert Advisor #" + IntegerToString(Magic_Number) + " turned off.";
   Comment(accountProtectionMessage);
   Print(accountProtectionMessage);

   Sleep(20 * 1000);
   ExpertRemove();
   OnDeinit(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetPosStats(void)
  {
   posStatCount = 0;
   posStatLots  = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i -= 1)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         const int ordType = OrderType();
         if(ordType != OP_BUY && ordType != OP_SELL) continue;

         posStatCount += 1;
         posStatLots  += OrderLots();
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateStats(void)
  {
   string comment = StringFormat("\n%s\nMagic number %d\n", robotTagline, Magic_Number);

   if(entryProtectionMessage != "")
      comment += "\n" + entryProtectionMessage;
   if(Pos_Stat)
      comment += GetPositionStats() + "\n";
   if(Robot_Stats)
      comment += GetRobotStats() + "\n";
   if(Max_Spread || Max_OpenPos || Max_OpenLots || MaxDailyLoss || Min_Equity || Max_Equity)
      comment += GetProtectionInfo();
   if(News_Priority != NewsFilter_Disabled)
      comment += GetNewsText() + "\n";

   RenderStats(comment);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetProtectionInfo(void)
  {
   string protectionInfo = "\n            ..:: Active Protections ::..\n";

   if(Max_Spread)
      protectionInfo += StringFormat("Max spread: %d, current: %d\n",
                                     Max_Spread, (int)MathRound((Ask() - Bid()) / _Point));
   if(Max_OpenPos)
      protectionInfo += StringFormat("Max open positions: %d, current: %d\n",
                                     Max_OpenPos, posStatCount);
   if(Max_OpenLots)
      protectionInfo += StringFormat("Max open lots: %.2f, current: %.2f\n",
                                     Max_OpenLots, posStatLots);
   if(MaxDailyLoss)
      protectionInfo += StringFormat("Max daily loss: %.2f, current: %.2f\n",
                                     -MathAbs(MaxDailyLoss), GetLastDaysProfit(1, -1));
   if(Min_Equity)
      protectionInfo += StringFormat("Min equity: %.2f, current: %.2f\n",
                                     Min_Equity, AccountInfoDouble(ACCOUNT_EQUITY));
   if(Max_Equity)
      protectionInfo += StringFormat("Max equity: %.2f, current: %.2f\n",
                                     Max_Equity, AccountInfoDouble(ACCOUNT_EQUITY));

   return protectionInfo;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetPositionStats(void)
  {
   const string positionStats = "\n            ..:: Position Stats ::..\n";

   if(posType==OP_FLAT)
      return positionStats +  "Position: no open position";

   return positionStats +
          StringFormat("Position: %s, Lots: %.2f, Profit %.2f\n",
                       (posType==OP_BUY) ? "Long" : "Short",
                       posLots, posProfit) +
          StringFormat("Open price: %s, Current price: %s\n",
                       DoubleToString(posPriceOpen, _Digits),
                       DoubleToString(posPriceCurr, _Digits)) +
          StringFormat("Stop Loss: %s, Take Profit: %s",
                       DoubleToString(posStopLoss,  _Digits),
                       DoubleToString(posTakeProfit,_Digits));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetRobotStats(void)
  {
   return "\n            ..:: Robot Stats ::..\n" +
          "Today        " + GetRobotStatsDays( 1) + "\n" +
          "This Week  "   + GetRobotStatsDays( 7) + "\n" +
          "This Month "   + GetRobotStatsDays(30);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetRobotStatsDays(int days)
  {
   double grossProfit     = 0;
   double grossLoss       = 0;
   int    histDealsCnt    = 0;
   double histDealsProfit = 0;

   const datetime timeCurrent = TimeCurrent();
   const datetime timeStart   = timeCurrent - days*PeriodSeconds(PERIOD_D1);
   const int      deals       = OrdersHistoryTotal();

   for(int i = 0; i < deals; i += 1)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() < timeStart) continue;
      const long dealMagic = OrderMagicNumber();
      if(dealMagic != Magic_Number && dealMagic != 0) continue;
      if(OrderSymbol() != _Symbol) continue;
      const int ordType = OrderType();
      if(ordType != OP_BUY && ordType != OP_SELL) continue;

      const double profit = OrderProfit() + OrderSwap() + OrderCommission();

      histDealsProfit += profit;
      histDealsCnt    += 1;

      if(profit >  sigma) grossProfit += profit;
      if(profit < -sigma) grossLoss   -= profit;
     }

   const double profitFactor = grossLoss > sigma ? grossProfit / grossLoss : grossProfit;

   return StringFormat("Trades: %d, Profit: %.2f, Profit factor: %.2f",
                       histDealsCnt, histDealsProfit, profitFactor);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RenderStats(string text)
  {
   string lines[];
   const int linesCount = StringSplit(text, '\n', lines);

   int lineWidth, lineHeight;
   TextGetSize(robotTagline, lineWidth, lineHeight);

   if(maxRectangles == 0)
      RectLabelCreate(0, "Stats_background", 0, 0, 30, lineWidth,
                      linesCount * lineHeight, GetChartBackColor(0));

   const color foreColor = GetChartForeColor(0);
   for(int i = 0; i < linesCount; i += 1)
     {
      if(lines[i] == "")
         lines[i] = " ";
      string labelName = "label" + IntegerToString(i);
      if(i < maxLabels)
         LabelUpdate(0, labelName, lines[i]);
      else
         LabelCreate(0, labelName, 0, 10, 20 + i * lineHeight,
                     CORNER_LEFT_UPPER, lines[i], "Arial", 10, foreColor);

      int lnWidth, lnHeight;
      TextGetSize(lines[i], lnWidth, lnHeight);
      if(lnWidth > lineWidth)
         lineWidth = lnWidth;
     }
   ObjectSetInteger(0, "Stats_background", OBJPROP_XSIZE,
                    (int) MathRound(lineWidth * 0.90));
   ObjectSetInteger(0, "Stats_background", OBJPROP_YSIZE,
                    linesCount * lineHeight);
   for(int i = linesCount; i < maxLabels; i += 1)
      LabelUpdate(0, "label" + IntegerToString(i), " ");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RectLabelCreate(
   const long             chartId    = 0,                 // chart's ID
   const string           name       = "RectLabel",       // label name
   const int              sub_window = 0,                 // subwindow index
   const int              x          = 0,                 // X coordinate
   const int              y          = 0,                 // Y coordinate
   const int              width      = 50,                // width
   const int              height     = 18,                // height
   const color            back_clr   = clrBlack,          // background color
   const ENUM_BORDER_TYPE border     = BORDER_SUNKEN,     // border type
   const ENUM_BASE_CORNER corner     = CORNER_LEFT_UPPER, // chart corner for anchoring
   const color            clr        = clrBlack,          // flat border color (Flat)
   const ENUM_LINE_STYLE  style      = STYLE_SOLID,       // flat border style
   const int              line_width = 0,                 // flat border width
   const bool             back       = false,             // in the background
   const bool             selection  = false,             // highlight to move
   const bool             hidden     = true,              // hidden in the object list
   const long             z_order    = 0)                 // priority for mouse click
  {
   if(!ObjectCreate(chartId, name, OBJ_RECTANGLE_LABEL, sub_window, 0, 0)) return;
   maxRectangles += 1;
   ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(chartId, name, OBJPROP_XSIZE,       width);
   ObjectSetInteger(chartId, name, OBJPROP_YSIZE,       height);
   ObjectSetInteger(chartId, name, OBJPROP_BGCOLOR,     back_clr);
   ObjectSetInteger(chartId, name, OBJPROP_BORDER_TYPE, border);
   ObjectSetInteger(chartId, name, OBJPROP_CORNER,      corner);
   ObjectSetInteger(chartId, name, OBJPROP_COLOR,       clr);
   ObjectSetInteger(chartId, name, OBJPROP_STYLE,       style);
   ObjectSetInteger(chartId, name, OBJPROP_WIDTH,       line_width);
   ObjectSetInteger(chartId, name, OBJPROP_BACK,        back);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE,  selection);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTED,    selection);
   ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,      hidden);
   ObjectSetInteger(chartId, name, OBJPROP_ZORDER,      z_order);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LabelCreate(
   const long              chartId=0,                // chart's ID
   const string            name="Label",             // label name
   const int               sub_window=0,             // subwindow index
   const int               x=0,                      // X coordinate
   const int               y=0,                      // Y coordinate
   const ENUM_BASE_CORNER  corner=CORNER_LEFT_UPPER, // chart corner for anchoring
   const string            text="Label",             // text
   const string            font="Arial",             // font
   const int               font_size=10,             // font size
   const color             clr=clrYellow,            // color
   const double            angle=0.0,                // text slope
   const ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER, // anchor type
   const bool              back=false,               // in the background
   const bool              selection=false,          // highlight to move
   const bool              hidden=true,              // hidden in the object list
   const long              z_order=0)                // priority for mouse click
  {
   if(!ObjectCreate(chartId, name, OBJ_LABEL, sub_window, 0 , 0)) return;
   maxLabels += 1;
   ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(chartId, name, OBJPROP_CORNER,     corner);
   ObjectSetString( chartId, name, OBJPROP_TEXT,       text);
   ObjectSetString( chartId, name, OBJPROP_FONT,       font);
   ObjectSetString( chartId, name, OBJPROP_TOOLTIP,    "\n");
   ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,   font_size);
   ObjectSetDouble( chartId, name, OBJPROP_ANGLE,      angle);
   ObjectSetInteger(chartId, name, OBJPROP_ANCHOR,     anchor);
   ObjectSetInteger(chartId, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(chartId, name, OBJPROP_BACK,       back);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, selection);
   ObjectSetInteger(chartId, name, OBJPROP_SELECTED,   selection);
   ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     hidden);
   ObjectSetInteger(chartId, name, OBJPROP_ZORDER,     z_order);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LabelUpdate(int chartId, string name, string text)
  {
   ObjectSetString(chartId, name, OBJPROP_TEXT, text);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color GetChartForeColor(const long chartId=0)
  {
   long foreColor = clrWhite;
   ChartGetInteger(chartId, CHART_COLOR_FOREGROUND, 0, foreColor);
   return (color) foreColor;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color GetChartBackColor(const long chartId=0)
  {
   long backColor = clrBlack;
   ChartGetInteger(chartId, CHART_COLOR_BACKGROUND, 0, backColor);
   return (color) backColor;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadNews(void)
  {
   loadNewsError = "";
   string error = "";
   const string newsContent = GetNewsContent(error);
   if(error != "")
     {
      loadNewsError = error;
      return;
     }

   if(newsContent == "")
     {
      loadNewsError = StringFormat("Cannot load news. Last error code: %d", GetLastError());
      return;
     }

   ParseNewsContent(newsContent, error);

   if(error != "")
      loadNewsError = error;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ParseNewsContent(string newsContent, string &error)
  {
   string lines[];
   const int linesLen = StringSplit(newsContent, '\n', lines);

   if(linesLen == -1)
     {
      error = "Cannot parse the news feed";
      return;
     }

   ArrayResize(newsRecords, linesLen);

   for(int i = 0; i < linesLen; i += 1)
     {
      string fields[];
      const int fieldsLen = StringSplit(lines[i], ';', fields);

      if(fieldsLen != 4)
        {
         error = "Cannot parse the news feed records";
         return;
        }

      NewsRecord record;
      record.time     = (datetime) StringToInteger(fields[0]);
      record.priority = fields[1];
      record.currency = fields[2];
      record.title    = fields[3];

      newsRecords[i] = record;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetNewsContent(string &error)
  {
   const string url = "https://forexsb.com/updates/news-feed.txt";

   char   reqBody[], resData[];
   string headers;

   ResetLastError();

   const int resCode  = WebRequest("GET", url, "", 10000, reqBody, resData, headers);
   const int resError = GetLastError();

   isNewsFeedOk = false;
   if(resError == ERR_FUNCTION_NOT_CONFIRMED)
     {
      error = "News Filter cannot access the news server.\n" +
              "Follow these steps to fix it:\n"
              " - open the \"Tool\" -> \"Options\" panel\n" +
              " - go to the \"Expert Advisors\" tab\n" +
              " - enable the \"Allow WebRequest for the listed URL:\" option.\n" +
              " - add \"https://forexsb.com\" in a field below.";
      return "";
     }

   if(resError != ERR_NO_MQLERROR)
     {
      error = StringFormat("News Filter connection error! Error code: %d", resError);
      return "";
     }

   if(resCode != 200)
     {
      error = StringFormat("Response code: %d", resCode);
      return "";
     }

   isNewsFeedOk = true;
   return CharArrayToString(resData, 0, ArraySize(resData), CP_UTF8);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetNewsText(void)
  {
   string newsText = "\n            ..:: Upcoming News ::..\n";
   if(loadNewsError != "") return newsText + loadNewsError;

   const datetime timeNow   = TimeGMT();
   const datetime timeShift = (datetime) MathRound((TimeLocal() - timeNow) / 3600.0) * 3600;
   const int      newsCount = ArraySize(newsRecords);

   for(int i = 0, count = 0; i < newsCount && count < News_ViewCount; i += 1)
     {
      const NewsRecord newsRecord = newsRecords[i];

      if(newsRecord.time < timeNow - News_AfterHigh * 60 ||
         !NewsIsAcceptedCurrency(newsRecord) ||
         !NewsIsAcceptedPriority(newsRecord))
         continue;

      const string newLine  = count > 0 ? "\n" : "";
      const string newsTime = TimeToString(newsRecord.time + timeShift, TIME_DATE | TIME_MINUTES);
      const string priority = newsRecord.priority == "high" ? "[high]" : "[med]";
      const string text     = StringFormat("%s%s %s %s %s", newLine, priority, newsTime,
                                           newsRecord.currency, newsRecord.title);
      StringAdd(newsText, text);
      count += 1;
     }

   return newsText;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewsIsAcceptedCurrency(const NewsRecord &newsRecord)
  {
   for(int i = 0; i < ArraySize(newsCurrencies); i += 1)
      if(newsCurrencies[i] == newsRecord.currency)
         return true;

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewsIsAcceptedPriority(const NewsRecord &newsRecord)
  {
   return (News_Priority == NewsFilter_HighAndMedium) ||
          (News_Priority == NewsFilter_HighOnly && newsRecord.priority == "high");
  }
//+------------------------------------------------------------------+
//| Gets the index of an active news or -1                           |
//+------------------------------------------------------------------+
int NewsFilterActive()
  {
   if(News_Priority == NewsFilter_Disabled)
      return -1;

   const datetime timeUtc = TimeGMT();
   const int      newsLen = ArraySize(newsRecords);
   for(int i = 0; i < newsLen; i += 1)
     {
      const NewsRecord news = newsRecords[i];
      if(!NewsIsAcceptedCurrency(news) || !NewsIsAcceptedPriority(news))
         continue;

      if(news.priority == "high" &&
         news.time - News_BeforeHigh * 60 - 15 <= timeUtc &&
         news.time + News_AfterHigh  * 60 - 15 >= timeUtc)
         return i;

      if(news.priority == "medium" &&
         news.time - News_BeforeMedium * 60 - 15 <= timeUtc &&
         news.time + News_AfterMedium  * 60 - 15 >= timeUtc)
         return i;
     }

   return -1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ParseNewsCurrenciesText()
  {
   string parts[], parsed[];
   const int partsLen = StringSplit(News_Currencies, ',', parts);
   ArrayResize(parsed, partsLen);
   int len = 0;
   for(int i = 0; i < partsLen; i += 1)
     {
      string part = parts[i];
      StringReplace(part, " ", "");
      if(StringLen(part) > 0)
        {
         parsed[i] = part;
         len += 1;
        }
     }

   ArrayResize(newsCurrencies, len);
   for(int i = 0; i < len; i += 1)
      newsCurrencies[i] = parsed[i];
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INIT_RETCODE ValidateInit()
  {
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
/*STRATEGY MARKET Premium Data; XAUUSD; M15 */
/*STRATEGY CODE {"properties":{"entryLots":0.1,"tradeDirectionMode":0,"oppositeEntrySignal":0,"stopLoss":4186,"takeProfit":8184,"useStopLoss":true,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Entry Time","listIndexes":[0,0,0,0,0],"numValues":[1,0,23,0,0,0]},{"name":"Accelerator Oscillator","listIndexes":[5,0,0,0,0],"numValues":[0,0,0,0,0,0]},{"name":"Accelerator Oscillator","listIndexes":[1,0,0,0,0],"numValues":[0,0,0,0,0,0]},{"name":"DeMarker","listIndexes":[6,0,0,0,0],"numValues":[1,0,0,0,0,0]}],"closeFilters":[{"name":"Pin Bar","listIndexes":[0,0,0,0,0],"numValues":[7,36,0,0,0,0]}]} */
