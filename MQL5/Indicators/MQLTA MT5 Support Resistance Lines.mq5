#property link          "https://www.earnforex.com/metatrader-indicators/support-resistance-lines/"
#property version       "1.02"
#property strict
#property copyright     "EarnForex.com - 2019-2023"
#property description   "This indicator shows support and resistance levels."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for damage or loss."
#property description   " "
#property description   "Find more on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

#property indicator_buffers 8
#property indicator_plots 8
#property indicator_label1 "BufferZero"
#property indicator_label2 "BufferOne"
#property indicator_label3 "BufferTwo"
#property indicator_label4 "BufferThree"
#property indicator_label5 "BufferFour"
#property indicator_label6 "BufferFive"
#property indicator_label7 "BufferSix"
#property indicator_label8 "BufferSeven"

enum ENUM_CUSTOMTIMEFRAMES
{
    CURRENT = PERIOD_CURRENT, // CURRENT PERIOD
    M1 = PERIOD_M1,           // M1
    M5 = PERIOD_M5,           // M5
    M15 = PERIOD_M15,         // M15
    M30 = PERIOD_M30,         // M30
    H1 = PERIOD_H1,           // H1
    H4 = PERIOD_H4,           // H4
    D1 = PERIOD_D1,           // D1
    W1 = PERIOD_W1,           // W1
    MN1 = PERIOD_MN1,         // MN1
};

enum ENUM_ACCURACY
{
    HIGH = 1,   // HIGH
    MEDIUM = 2, // MEDIUM
    LOW = 3,    // LOW
};


enum ENUM_THICKNESS
{
    ONE = 1,   // 1
    TWO = 2,   // 2
    THREE = 3, // 3
    FOUR = 4,  // 4
    FIVE = 5,  // 5
};

enum ENUM_WHENNOTIFY
{
    SAFETY = 0, // SAFE AREA
    DANGER = 1, // DANGER AREA
};

enum ENUM_FILLBUFFERS
{
    LEVELS = 0,    // SUPPORT/RESISTANCE LEVELS
    DISTANCES = 1, // DISTANCES FROM LEVELS
};

input string Comment_1 = "====================";    // Indicator Settings
input ENUM_TIMEFRAMES SRTimeframe = PERIOD_CURRENT; // Timeframe to Analyze
input ENUM_ACCURACY SRAccuracy = MEDIUM;            // Number of Levels
input int SafeDistance = 50;                        // Safety Distance From Closest Level (points)
input string Comment_2a = "====================";   // iCustom Utility (For Expert Advisors)
input ENUM_FILLBUFFERS FillBuffersWith = LEVELS;    // Fill Buffers With
input string Comment_2 = "====================";    // Limits for the Analysis
input int BarsToIgnore = 0;                         // Recent Candles to Ignore
input int MaxBarsExt = 1000;                        // Bars to Analyze
input int MaxRange = 0;                             // Max Price Range to Analyze (points) (0=No Limit)
input string Comment_3 = "====================";    // Notification Options
input bool EnableNotify = false;                    // Enable Notifications feature
input ENUM_WHENNOTIFY WhenNotify = DANGER;          // Notify In
input bool SendAlert = true;                        // Send Alert Notification
input bool SendApp = false;                         // Send Notification to Mobile
input bool SendEmail = false;                       // Send Notification via Email
input string Comment_4 = "====================";    // Graphical Objects
input bool DrawLinesEnabled = true;                 // Draw Lines
input color ResistanceColor = clrGreen;             // Resistance Color
input color SupportColor = clrRed;                  // Support Color
input ENUM_THICKNESS LineThickness = THREE;         // Line Thickness
input bool DrawZones = false;                        // Draw S/R Zones
input color ZoneResistanceColor = clrMediumSeaGreen; // Resistance Color
input color ZoneSupportColor = clrLightSalmon;       // Support Color
input bool DrawWindowEnabled = true;                // Draw Window
input int Xoff = 20;                                // Horizontal spacing for the control panel
input int Yoff = 20;                                // Vertical spacing for the control panel
input string IndicatorName = "MQLTA-SR";            // Indicator Name (to name the objects)

int MaxBars = 0;
int ATRPeriod = 100;
double Array[];
int CalculatedBars = 0;
double LevelAbove = 0;
double LevelBelow = 0;
int DistanceFromSupport = INT_MAX;
int DistanceFromResistance = INT_MAX;
int MinDistance = 0;
int LastNotificationStatus = -2; // -2 = first attachment to the chart.
double NotificationLevel = 0;
datetime LastNotificationTime = 0;
double LastNotificationLevel = 0;
bool Waiting = false;

int ATRHandle, FractalsHandle;
double BufferFractalsUp[], BufferFractalsDown[];
double BufferATR[];

double BufferZero[];
double BufferOne[];
double BufferTwo[];
double BufferThree[];
double BufferFour[];
double BufferFive[];
double BufferSix[];
double BufferSeven[];

double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName);

    CleanChart();
    InitializeHandles();

    SetIndexBuffer(0, BufferZero, INDICATOR_DATA);
    SetIndexBuffer(1, BufferOne, INDICATOR_DATA);
    SetIndexBuffer(2, BufferTwo, INDICATOR_DATA);
    SetIndexBuffer(3, BufferThree, INDICATOR_DATA);
    SetIndexBuffer(4, BufferFour, INDICATOR_DATA);
    SetIndexBuffer(5, BufferFive, INDICATOR_DATA);
    SetIndexBuffer(6, BufferSix, INDICATOR_DATA);
    SetIndexBuffer(7, BufferSeven, INDICATOR_DATA);

    ArraySetAsSeries(BufferZero, true);
    ArraySetAsSeries(BufferOne, true);
    ArraySetAsSeries(BufferTwo, true);
    ArraySetAsSeries(BufferThree, true);
    ArraySetAsSeries(BufferFour, true);
    ArraySetAsSeries(BufferFive, true);
    ArraySetAsSeries(BufferSix, true);
    ArraySetAsSeries(BufferSeven, true);

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(26 * DPIScale);
    PanelMovY = (int)MathRound(26 * DPIScale);
    PanelLabX = (int)MathRound(200 * DPIScale);
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    MaxBars = MaxBarsExt;
    if (iBars(Symbol(), SRTimeframe) < MaxBars + BarsToIgnore)
    {
        MaxBars = iBars(Symbol(), SRTimeframe) - BarsToIgnore;
        Print("Please load more historical candles, calculation on only ", MaxBars, " bars.");
        if (MaxBars <= 0) return 0;
    }
    if (CopyBuffer(FractalsHandle, 0, 0, MaxBars, BufferFractalsUp) <= 0 ||
        CopyBuffer(FractalsHandle, 1, 0, MaxBars, BufferFractalsDown) <= 0 ||
        CopyBuffer(ATRHandle, 0, 0, MaxBars, BufferATR) <= 0)
    {
        Print("Waitning for indicator data to load...");
        Waiting = true;
        return 0;
    }
    else if (Waiting)
    {
        Waiting = false;
        Print("Indicator data ready.");
    }
    if (CalculatedBars != prev_calculated)
    {
        CalculateLevels();
        CalculatedBars = prev_calculated;
    }
    CalculatedBars = prev_calculated;
    
    LevelAbove = CalculateLevelAbove();
    LevelBelow = CalculateLevelBelow();
    
    if (LevelAbove > 0) DistanceFromResistance = int((LevelAbove - iClose(Symbol(), PERIOD_CURRENT, 0)) / Point());
    else DistanceFromResistance = INT_MAX; // No resistance levels.
    if (LevelBelow > 0) DistanceFromSupport = int((iClose(Symbol(), PERIOD_CURRENT, 0) - LevelBelow) / Point());
    else DistanceFromSupport = INT_MAX; // No support levels.

    if (((DistanceFromResistance > 0) && (DistanceFromResistance < DistanceFromSupport)) || (DistanceFromSupport == INT_MAX))
    {
        MinDistance = DistanceFromResistance;
        NotificationLevel = LevelAbove;
    }
    if (((DistanceFromSupport > 0)    && (DistanceFromSupport < DistanceFromResistance)) || (DistanceFromResistance == INT_MAX))
    {
        MinDistance = DistanceFromSupport;
        NotificationLevel = LevelBelow;
    }

    FillBuffers();
    if (EnableNotify) Notify();
    if (DrawLinesEnabled) DrawLines();
    if (DrawWindowEnabled) DrawPanel();
    
    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

void CleanChart()
{
    ObjectsDeleteAll(0, IndicatorName);
}

void InitializeHandles()
{
    ATRHandle = iATR(NULL, SRTimeframe, ATRPeriod);
    FractalsHandle = iFractals(NULL, SRTimeframe);
    ArraySetAsSeries(BufferFractalsUp, true);
    ArraySetAsSeries(BufferFractalsDown, true);
    ArraySetAsSeries(BufferATR, true);
}

void CalculateLevels()
{
    double Highest = iHigh(NULL, SRTimeframe, iHighest(NULL, SRTimeframe, MODE_HIGH, MaxBars, 0));
    double Lowest = iLow(NULL, SRTimeframe, iLowest(NULL, SRTimeframe, MODE_LOW, MaxBars, 0));
    double Step = NormalizeDouble(BufferATR[0] * SRAccuracy, Digits());

    if (Step == 0)
    {
        Print("Not enough historical data, please load more candles for the selected timeframe.");
        return;
    }

    int Steps = (int)MathCeil((Highest - Lowest) / Step) + 1;
    double MidRange = MaxRange / 2 * Point();
    ArrayResize(Array, Steps);
    ArrayInitialize(Array, 0);

    for (int i = 0; i < ArraySize(Array); i++)
    {
        double StartRange = Lowest + Step * i;
        double EndRange = Lowest + Step * (i + 1);
        if ((MidRange > 0) && (StartRange < iClose(Symbol(), PERIOD_CURRENT, 0) - MidRange)) continue;
        if ((MidRange > 0) && (EndRange   > iClose(Symbol(), PERIOD_CURRENT, 0) + MidRange)) continue;
        int BarCount = 0;
        double AvgPrice = 0;
        double TotalPrice = 0;
        Array[i] = 0;
        for (int j = BarsToIgnore; j < MaxBars + BarsToIgnore; j++)
        {
            double Fractal = 0;
            if (BufferFractalsUp[j - BarsToIgnore] != EMPTY_VALUE) Fractal = BufferFractalsUp[j - BarsToIgnore];
            else if (BufferFractalsDown[j - BarsToIgnore] != EMPTY_VALUE) Fractal = BufferFractalsDown[j - BarsToIgnore];
            double AvgValue = 0;

            if ((Fractal >= StartRange) && (Fractal <= EndRange))
            {
                BarCount++;
                AvgValue = Fractal;
                TotalPrice += AvgValue;
            }
        }
        if (BarCount > 0) AvgPrice = NormalizeDouble(TotalPrice / BarCount, Digits());

        Array[i] = AvgPrice;
    }
}

void FillBuffers()
{
    BufferZero[0] = 0;
    BufferOne[0] = 0;
    BufferTwo[0] = 0;
    BufferThree[0] = 0;
    BufferFour[0] = 0;
    BufferFive[0] = 0;
    BufferSix[0] = 0;
    BufferSeven[0] = 0;
    if (FillBuffersWith == LEVELS)
    {
        int j = 0;
        for (int i = 0; i < ArraySize(Array); i++)
        {
            if (Array[i] > iClose(Symbol(), PERIOD_CURRENT, 0))
            {
                if (j == 0)
                {
                    BufferFour[0] = NormalizeDouble(Array[i], Digits());
                }
                else if (j == 1)
                {
                    BufferFive[0] = NormalizeDouble(Array[i], Digits());
                }
                else if (j == 2)
                {
                    BufferSix[0] = NormalizeDouble(Array[i], Digits());
                }
                else if (j == 3)
                {
                    BufferSeven[0] = NormalizeDouble(Array[i], Digits());
                }
                j++;
                if (j == 4) break;
            }
        }
        j = 0;
        for (int i = ArraySize(Array) - 1; i >= 0; i--)
        {
            if (Array[i] > 0 && Array[i] < iClose(Symbol(), PERIOD_CURRENT, 0))
            {
                if (j == 0)
                {
                    BufferThree[0] = NormalizeDouble(Array[i], Digits());
                }
                else if (j == 1)
                {
                    BufferTwo[0] = NormalizeDouble(Array[i], Digits());
                }
                else if (j == 2)
                {
                    BufferOne[0] = NormalizeDouble(Array[i], Digits());
                }
                else if (j == 3)
                {
                    BufferZero[0] = NormalizeDouble(Array[i], Digits());
                }
                j++;
                if (j == 4) break;
            }
        }
    }
    if (FillBuffersWith == DISTANCES)
    {
        if ((MinDistance > 0) && (MinDistance > SafeDistance)) BufferZero[0] = 1;
        BufferOne[0] = LevelAbove;
        BufferTwo[0] = LevelBelow;
        BufferThree[0] = DistanceFromResistance;
        BufferFour[0] = DistanceFromSupport;
    }
}

void Notify()
{
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    if ((WhenNotify == DANGER) && (MinDistance > SafeDistance))
    {
        LastNotificationStatus = -1; // Retourned to uncertain.
        return;
    }
    if ((WhenNotify == SAFETY) && (MinDistance < SafeDistance))
    {
        LastNotificationStatus = -1; // Retourned to uncertain.
        return;
    }
    
    if (LastNotificationStatus == -2) // Skip first alert on attachment.
    {
        LastNotificationStatus = WhenNotify;
        LastNotificationLevel = NotificationLevel;
        return;
    }

    if ((LastNotificationStatus == WhenNotify) && (LastNotificationLevel == NotificationLevel)) return; // Already notified about this situation.
    LastNotificationStatus = WhenNotify;

    if (LastNotificationTime == iTime(Symbol(), Period(), 0)) // Same bar - ignore if the same level.
    {
        if (LastNotificationLevel == NotificationLevel) return; // Don't alert if the same level is to be alerted within a short period of time.
        Print(LastNotificationTime, " - ", LastNotificationLevel);
    }

    string EmailSubject = IndicatorName + " " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + IndicatorName + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    if (WhenNotify == DANGER) EmailBody += "The price is approaching a support/resistance level: " + DoubleToString(NotificationLevel, _Digits);
    else if (WhenNotify == SAFETY) EmailBody += "The price is at a safe distance from the closest support/resistance level: " + DoubleToString(NotificationLevel, _Digits);
    string AlertText = "";
    if (WhenNotify == DANGER) AlertText += "Price is in Danger Zone of " + DoubleToString(NotificationLevel, _Digits);
    else if (WhenNotify == SAFETY) AlertText += "Price is in Safe Zone from " + DoubleToString(NotificationLevel, _Digits);
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + ": ";
    if (WhenNotify == DANGER) AppText += "Price is in Danger Zone of " + DoubleToString(NotificationLevel, _Digits);
    else if (WhenNotify == SAFETY) AppText += "Price is in Safe Zone from " + DoubleToString(NotificationLevel, _Digits);
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    LastNotificationLevel = NotificationLevel;
    LastNotificationTime = iTime(Symbol(), Period(), 0);
}

void DrawLines()
{
    CleanLines();
    for (int i = 0; i < ArraySize(Array); i++)
    {
        if (Array[i] > 0)
        {
            int LineNumber = int(Array[i] / Point());
            string LineName = IndicatorName + "-HLINE-" + IntegerToString(LineNumber);
            color Color = (Array[i] > iClose(Symbol(), PERIOD_CURRENT, 0)) ? ResistanceColor : SupportColor;
            ObjectCreate(0, LineName, OBJ_HLINE, 0, 0, Array[i]);
            ObjectSetInteger(0, LineName, OBJPROP_COLOR, Color);
            ObjectSetInteger(0, LineName, OBJPROP_WIDTH, LineThickness);
            ObjectSetInteger(0, LineName, OBJPROP_SELECTABLE, false);
            
            if (DrawZones)
            {
                string ZoneName = IndicatorName + "-HLINE-Z-" + IntegerToString(LineNumber);
                Color = (Array[i] > iClose(Symbol(), PERIOD_CURRENT, 0)) ? ZoneResistanceColor : ZoneSupportColor;
                double UpperPrice = Array[i] + SafeDistance * _Point;
                double LowerPrice = Array[i] - SafeDistance * _Point;
                ObjectCreate(0, ZoneName, OBJ_RECTANGLE, 0, iTime(Symbol(), Period(), MaxBars - 1), LowerPrice, D'2049.12.31', UpperPrice);
                ObjectSetInteger(0, ZoneName, OBJPROP_COLOR, Color);
                ObjectSetInteger(0, ZoneName, OBJPROP_FILL, true);
                ObjectSetInteger(0, ZoneName, OBJPROP_BACK, true);
                ObjectSetInteger(0, ZoneName, OBJPROP_SELECTABLE, false);
            }
        }
    }
}

void CleanLines()
{
    ObjectsDeleteAll(0, IndicatorName + "-HLINE-");
}

double CalculateLevelAbove()
{
    double Level = 0;
    for (int i = 0; i < ArraySize(Array); i++)
    {
        if (Array[i] >= iClose(Symbol(), PERIOD_CURRENT, 0))
        {
            Level = NormalizeDouble(Array[i], Digits());
            break;
        }
    }
    return Level;
}

double CalculateLevelBelow()
{
    double Level = 0;
    for (int i = ArraySize(Array) - 1; i >= 0; i--)
    {
        if ((Array[i] > 0) && (Array[i] <= iClose(Symbol(), PERIOD_CURRENT, 0)))
        {
            Level = NormalizeDouble(Array[i], Digits());
            break;
        }
    }
    return Level;
}

string PanelBase = IndicatorName + "-P-BAS";
string PanelLabel = IndicatorName + "-P-LAB";
string PanelDAbove = IndicatorName + "-P-DABOVE";
string PanelDBelow = IndicatorName + "-P-DBELOW";
string PanelSig = IndicatorName + "-P-SIG";
void DrawPanel()
{
    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    ObjectCreate(0, PanelLabel, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, PanelLabel, OBJPROP_XDISTANCE, Xoff + 2);
    ObjectSetInteger(0, PanelLabel, OBJPROP_YDISTANCE, Yoff + 2);
    ObjectSetInteger(0, PanelLabel, OBJPROP_XSIZE, PanelLabX);
    ObjectSetInteger(0, PanelLabel, OBJPROP_YSIZE, PanelLabY);
    ObjectSetInteger(0, PanelLabel, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelLabel, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelLabel, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelLabel, OBJPROP_READONLY, true);
    ObjectSetInteger(0, PanelLabel, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetString(0, PanelLabel, OBJPROP_TOOLTIP, "Supprt/Resistance Lines");
    ObjectSetString(0, PanelLabel, OBJPROP_TEXT, "MQLTA SUPP-RES LINES");
    ObjectSetString(0, PanelLabel, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, PanelLabel, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, PanelLabel, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelLabel, OBJPROP_COLOR, clrNavy);
    ObjectSetInteger(0, PanelLabel, OBJPROP_BGCOLOR, clrKhaki);
    ObjectSetInteger(0, PanelLabel, OBJPROP_BORDER_COLOR, clrBlack);

    string DAboveText = "";
    if (DistanceFromResistance != INT_MAX)
    {
        DAboveText = "To next resistance: " + IntegerToString(DistanceFromResistance) + " points";
    }
    else
    {
        DAboveText = "No resistance found";
    }
    ObjectCreate(0, PanelDAbove, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_XDISTANCE, Xoff + 2);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_YDISTANCE, Yoff + (PanelMovY + 1)*Rows + 2);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_XSIZE, PanelLabX);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_YSIZE, PanelLabY);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_READONLY, true);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, PanelDAbove, OBJPROP_TOOLTIP, "Distance To The Above Level of Resistance");
    ObjectSetInteger(0, PanelDAbove, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetString(0, PanelDAbove, OBJPROP_FONT, "Consolas");
    ObjectSetString(0, PanelDAbove, OBJPROP_TEXT, DAboveText);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_COLOR, clrNavy);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_BGCOLOR, clrKhaki);
    ObjectSetInteger(0, PanelDAbove, OBJPROP_BORDER_COLOR, clrBlack);
    Rows++;

    string DBelowText = "";
    if (DistanceFromSupport != INT_MAX)
    {
        DBelowText = "To next support: " + IntegerToString(DistanceFromSupport) + " points";
    }
    else
    {
        DBelowText = "No support found";
    }
    ObjectCreate(0, PanelDBelow, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_XDISTANCE, Xoff + 2);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_YDISTANCE, Yoff + (PanelMovY + 1)*Rows + 2);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_XSIZE, PanelLabX);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_YSIZE, PanelLabY);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_READONLY, true);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, PanelDBelow, OBJPROP_TOOLTIP, "Distance To The Below Level of Support");
    ObjectSetInteger(0, PanelDBelow, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetString(0, PanelDBelow, OBJPROP_FONT, "Consolas");
    ObjectSetString(0, PanelDBelow, OBJPROP_TEXT, DBelowText);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_COLOR, clrNavy);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_BGCOLOR, clrKhaki);
    ObjectSetInteger(0, PanelDBelow, OBJPROP_BORDER_COLOR, clrBlack);
    Rows++;

    string SigText = "";
    color SigColor = clrNavy;
    color SigBack = clrKhaki;
    if (MinDistance > SafeDistance)
    {
        SigText += "SAFE TO TRADE";
        SigColor = clrWhite;
        SigBack = clrDarkGreen;
    }
    else
    {
        SigText += "WAIT TO TRADE";
        SigColor = clrWhite;
        SigBack = clrDarkRed;
    }
    ObjectCreate(0, PanelSig, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, PanelSig, OBJPROP_XDISTANCE, Xoff + 2);
    ObjectSetInteger(0, PanelSig, OBJPROP_YDISTANCE, Yoff + (PanelMovY + 1)*Rows + 2);
    ObjectSetInteger(0, PanelSig, OBJPROP_XSIZE, PanelLabX);
    ObjectSetInteger(0, PanelSig, OBJPROP_YSIZE, PanelLabY);
    ObjectSetInteger(0, PanelSig, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelSig, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelSig, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelSig, OBJPROP_READONLY, true);
    ObjectSetInteger(0, PanelSig, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelSig, OBJPROP_ALIGN, ALIGN_CENTER);
    ObjectSetString(0, PanelSig, OBJPROP_FONT, "Consolas");
    ObjectSetString(0, PanelSig, OBJPROP_TOOLTIP, "Suggestion Based On The Safe Distance Set");
    ObjectSetString(0, PanelSig, OBJPROP_TEXT, SigText);
    ObjectSetInteger(0, PanelSig, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelSig, OBJPROP_COLOR, SigColor);
    ObjectSetInteger(0, PanelSig, OBJPROP_BGCOLOR, SigBack);
    ObjectSetInteger(0, PanelSig, OBJPROP_BORDER_COLOR, clrBlack);
    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1)*Rows + 3);
}
//+------------------------------------------------------------------+