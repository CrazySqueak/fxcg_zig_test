
#include <stddef.h>

// https://www.cemetech.net/forum/viewtopic.php?p=170835#170835
// Credit to cfxm

#define RTC             (*(volatile struct rtc_regs *)0xA413FEC0)
typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned char bool;

struct rtc_regs {
        union {
            uchar REG8;
            struct {
                uchar   :1;
                uchar   H1:1;
                uchar   H2:1;
                uchar   H4:1;
                uchar   H8:1;
                uchar   H16:1;
                uchar   H32:1;
                uchar   H64:1;
                uchar   :8;
            } BIT;
        } R64CNT; /* 64-Hz Counter */
        union {
            uchar REG8;
            struct {
                uchar   :1;
                uchar   S1:3; /* Second Tens */
                uchar   S0:4; /* Second Ones */
                uchar   :8;
            } BIT;
        } RSECCNT; /* Second Counter */
        union {
            uchar REG8;
            struct {
                uchar   :1;
                uchar   M1:3; /* Minute Tens */
                uchar   M0:4; /* Minute Ones */
                uchar   :8;
            } BIT;
        } RMINCNT; /* Minute Counter */
        union {
            uchar REG8;
            struct {
                uchar   :2;
                uchar   H1:2; /* Hour Tens */
                uchar   H0:4; /* Hour Ones */
                uchar   :8;
            } BIT;
        } RHRCNT; /* Hour Counter */
        union {
            uchar REG8;
            struct {
                uchar   :5;
                uchar   WK:3; /* Day of Week Setting */
                uchar   :8;
            } BIT;
        } RWKCNT; /* Day of Week Counter */
        union {
            uchar REG8;
            struct {
                uchar   :2;
                uchar   D1:2; /* Date Tens */
                uchar   D0:4; /* Date Ones */
                uchar   :8;
            } BIT;
        } RDAYCNT; /* Date Counter */
        union {
            uchar REG8;
            struct {
                uchar   :3;
                uchar   M1:1; /* Month Tens */
                uchar   M0:4; /* Month Ones */
                uchar   :8;
            } BIT;
        } RMONCNT; /* Month Counter */
        union {
            ushort REG16;
            struct {
                ushort  Y3:4; /* Year Thousands */
                ushort  Y2:4; /* Year Hundreds */
                ushort  Y1:4; /* Year Tens */
                ushort  Y0:4; /* Year Ones */
            } BIT;
        } RYRCNT; /* Year Counter */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Second Alarm Enable */
                uchar   S1:3; /* Second Tens */
                uchar   S0:4; /* Second Ones */
                uchar   :8;
            } BIT;
        } RSECAR; /* Second Alarm */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Minute Alarm Enable */
                uchar   M1:3; /* Minute Tens */
                uchar   M0:4; /* Minute Ones */
                uchar   :8;
            } BIT;
        } RMINAR; /* Minute Alarm */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Hour Alarm Enable */
                uchar   :1;
                uchar   H1:2; /* Hour Tens */
                uchar   H0:4; /* Hour Ones */
                uchar   :8;
            } BIT;
        } RHRAR; /* Hour Alarm */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Day of Week Alarm Enable */
                uchar   :4;
                uchar   WK:3; /* Day of Week Setting */
                uchar   :8;
            } BIT;
        } RWKAR; /* Day of Week Alarm */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Date Alarm Enable */
                uchar   :1;
                uchar   D1:2; /* Date Tens */
                uchar   D0:4; /* Date Ones */
                uchar   :8;
            } BIT;
        } RDAYAR; /* Date Alarm */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Month Alarm Enable */
                uchar   :2;
                uchar   M1:1; /* Month Tens */
                uchar   M0:4; /* Month Ones */
                uchar   :8;
            } BIT;
        } RMONAR; /* Month Alarm */
        union {
            uchar REG8;
            struct {
                uchar   CF:1; /* Carry Flag */
                uchar   :2;
                uchar   CIE:1; /* Carry Interrupt Enable */
                uchar   AIE:1; /* Alarm Interrupt Enable */
                uchar   :2;
                uchar   AF:1; /* Alarm Flag */
                uchar   :8;
            } BIT;
        } RCR1; /* Control 1 */
        union {
            uchar REG8;
            struct {
                uchar   PEF:1; /* Periodic Interrupt Enable */
                uchar   PES:3; /* Periodic Interrupt Setting */
                uchar   RTCEN:1; /* Oscillator Control */
                uchar   ADJ:1; /* 30-Second Adjustment */
                uchar   RESET:1; /* Reset Bit */
                uchar   START:1; /* Start Bit */
                uchar   :8;
            } BIT;
        } RCR2; /* Control 2 */
        union {
            ushort REG16;
            struct {
                ushort  Y3:4; /* Year Thousands */
                ushort  Y2:4; /* Year Hundreds */
                ushort  Y1:4; /* Year Tens */
                ushort  Y0:4; /* Year Ones */
                ushort  :16;
            } BIT;
        } RYRAR; /* Year Alarm */
        union {
            uchar REG8;
            struct {
                uchar   ENB:1; /* Year Alarm Enable */
                uchar   :7;
                uchar   :8;
            } BIT;
        } RCR3; /* Control 3 */
};

struct rtc_setup {
        uchar   dayofweek; /* 1..7 (Monday, ...) */
        uchar   second; /* 0..59 */
        uchar   minute; /* 0..59 */
        uchar   hour; /* 0..23 */
        uchar   day; /* 1..31 */
        uchar   month; /* 1..12 */
        ushort  year;
};

void RTC_Set(const struct rtc_setup *sp);

void RTC_Read(struct rtc_setup *sp);