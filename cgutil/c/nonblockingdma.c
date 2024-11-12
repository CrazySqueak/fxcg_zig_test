// From https://prizm.cemetech.net/Useful_Routines/Non-blocking_DMA/
// See also: https://www.cemetech.net/forum/viewtopic.php?p=292621#292621

#include <fxcg/display.h>
#define LCD_GRAM    0x202
#define LCD_BASE    0xB4000000
#define SYNCO() __asm__ volatile("SYNCO\n\t":::"memory");
// Module Stop Register 0
#define MSTPCR0     (volatile unsigned*)0xA4150030
// DMA0 operation register
#define DMA0_DMAOR  (volatile unsigned short*)0xFE008060
#define DMA0_SAR_0  (volatile unsigned*)0xFE008020
#define DMA0_DAR_0  (volatile unsigned*)0xFE008024
#define DMA0_TCR_0  (volatile unsigned*)0xFE008028
#define DMA0_CHCR_0 (volatile unsigned*)0xFE00802C
void DmaWaitNext(void){
    while(1){
        if((*DMA0_DMAOR)&4)//Address error has occurred stop looping
            break;
        if((*DMA0_CHCR_0)&2)//Transfer is done
            break;
    }
    SYNCO();
    *DMA0_CHCR_0&=~1;
    *DMA0_DMAOR=0;
}
void DoDMAlcdNonblockStrip(unsigned y1,unsigned y2){
    Bdisp_WriteDDRegister3_bit7(1);
    Bdisp_DefineDMARange(6,389,y1,y2);
    Bdisp_DDRegisterSelect(LCD_GRAM);

    *MSTPCR0&=~(1<<21);//Clear bit 21
    *DMA0_CHCR_0&=~1;//Disable DMA on channel 0
    *DMA0_DMAOR=0;//Disable all DMA
    *DMA0_SAR_0=((unsigned)(GetVRAMAddress()+(y1*384*2)))&0x1FFFFFFF;//Source address is VRAM
    *DMA0_DAR_0=LCD_BASE&0x1FFFFFFF;//Destination is LCD
    *DMA0_TCR_0=((y2-y1+1)*384)/16;//Transfer count bytes/32
    *DMA0_CHCR_0=0x00101400;
    *DMA0_DMAOR|=1;//Enable DMA on all channels
    *DMA0_DMAOR&=~6;//Clear flags
    *DMA0_CHCR_0|=1;//Enable channel0 DMA
}
void DoDMAlcdNonblock(void){
    DoDMAlcdNonblockStrip(0,215);
}