#include "rtc_datetime.h"

void RTC_Set(const struct rtc_setup *sp)
{
        if (sp == NULL)
            return;

        RTC.RCR2.BIT.START = 0;
        RTC.RCR2.BIT.RTCEN = 0;
        RTC.RCR2.BIT.RESET = 1;
        RTC.RSECCNT.BIT.S0 = sp->second % 10;
        RTC.RSECCNT.BIT.S1 = sp->second / 10;
        RTC.RMINCNT.BIT.M0 = sp->minute % 10;
        RTC.RMINCNT.BIT.M1 = sp->minute / 10;
        RTC.RHRCNT.BIT.H0 = sp->hour % 10;
        RTC.RHRCNT.BIT.H1 = sp->hour / 10;
        RTC.RWKCNT.BIT.WK = sp->dayofweek % 7;
        RTC.RDAYCNT.BIT.D0 = sp->day % 10;
        RTC.RDAYCNT.BIT.D1 = sp->day / 10;
        RTC.RMONCNT.BIT.M0 = sp->month % 10;
        RTC.RMONCNT.BIT.M1 = sp->month / 10;
        RTC.RYRCNT.BIT.Y0 = sp->year % 10;
        RTC.RYRCNT.BIT.Y1 = (sp->year % 100) / 10;
        RTC.RYRCNT.BIT.Y2 = (sp->year / 100) % 10;
        RTC.RYRCNT.BIT.Y3 = sp->year / 1000;
        RTC.RCR2.BIT.RTCEN = 1;
        RTC.RCR2.BIT.START = 1;

        return;
}

void RTC_Read(struct rtc_setup *sp)
{
        bool flag;

        if (sp == NULL)
            return;

        flag = RTC.RCR1.BIT.CIE;
        RTC.RCR1.BIT.CIE = 0;
        do {
            RTC.RCR1.BIT.CF = 0;
            sp->second = RTC.RSECCNT.BIT.S1 * 10 + RTC.RSECCNT.BIT.S0;
            sp->minute = RTC.RMINCNT.BIT.M1 * 10 + RTC.RMINCNT.BIT.M0;
            sp->hour = RTC.RHRCNT.BIT.H1 * 10 + RTC.RHRCNT.BIT.H0;
            sp->dayofweek = (RTC.RWKCNT.BIT.WK > 0)? RTC.RWKCNT.BIT.WK : 7;
            sp->day = RTC.RDAYCNT.BIT.D1 * 10 + RTC.RDAYCNT.BIT.D0;
            sp->month = RTC.RMONCNT.BIT.M1 * 10 + RTC.RMONCNT.BIT.M0;
            sp->year = RTC.RYRCNT.BIT.Y3 * 1000 + RTC.RYRCNT.BIT.Y2 * 100 +
              RTC.RYRCNT.BIT.Y1 * 10 + RTC.RYRCNT.BIT.Y0;
        } while (RTC.RCR1.BIT.CF != 0);
        RTC.RCR1.BIT.CIE = flag;

        return;
}