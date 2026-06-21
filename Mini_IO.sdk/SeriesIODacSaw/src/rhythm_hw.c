/* Board I/O and interrupt glue.
 *
 * Interrupt handlers stay intentionally small: they only acknowledge hardware
 * and latch events. The main loop consumes those events outside interrupt
 * context so VS1003B streaming and VGA packet updates stay predictable.
 */
#include "rhythm_game.h"

void InitHardware(void)
{
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI_OFFSET, 0xFFFFU);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_DATA2_OFFSET, VS_GPIO_IDLE | VS_LED_INIT);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_TRI_OFFSET, 0x0000U);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA_OFFSET, 0xFFU);
    Xil_Out32(GPIO_SEVENSEG_BASEADDR + XGPIO_DATA2_OFFSET, 0xFFU);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_TRI_OFFSET, 0x001FU);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_TRI2_OFFSET, 0x0000U);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA2_OFFSET, 0x12U);
    CurrentButtons = (u8)(Xil_In32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA_OFFSET) & 0x1FU);
    LastButtons = CurrentButtons;

    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET, 0);
    Xil_Out32(TIMER_BASEADDR + XTC_TLR_OFFSET, TIMER_LOAD_VALUE);
    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET, XTC_CSR_LOAD_MASK);
    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET,
              XTC_CSR_ENABLE_TMR_MASK |
              XTC_CSR_ENABLE_INT_MASK |
              XTC_CSR_AUTO_RELOAD_MASK |
              XTC_CSR_DOWN_COUNT_MASK);
}

static void TimerInterruptHandler(void *CallbackRef)
{
    (void)CallbackRef;
    u32 status = Xil_In32(TIMER_BASEADDR + XTC_TCSR_OFFSET);
    if ((status & XTC_CSR_INT_OCCURED_MASK) != 0U) {
        Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET, status | XTC_CSR_INT_OCCURED_MASK);
        ++TimerTicksPending;
    }
}

static void ButtonInterruptHandler(void *CallbackRef)
{
    u8 buttons;
    u8 pressed;

    (void)CallbackRef;
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    buttons = (u8)(Xil_In32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_DATA_OFFSET) & 0x1FU);
    pressed = buttons & (u8)~LastButtons;
    LastButtons = buttons;
    CurrentButtons = buttons;
    ButtonPressedEvents |= pressed;
}

static void SwitchInterruptHandler(void *CallbackRef)
{
    (void)CallbackRef;
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    SwitchEventPending = 1U;
}

void InitInterrupts(void)
{
    TimerTicksPending = 0U;
    ButtonPressedEvents = 0U;
    SwitchEventPending = 0U;
    Xil_Out32(TIMER_BASEADDR + XTC_TCSR_OFFSET,
              Xil_In32(TIMER_BASEADDR + XTC_TCSR_OFFSET) | XTC_CSR_INT_OCCURED_MASK);

    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_IER_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_BUTTON_RGB_BASEADDR + XGPIO_GIE_OFFSET, XGPIO_GIE_GINTR_ENABLE_MASK);

    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_IER_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_ISR_OFFSET, XGPIO_IR_CH1_MASK);
    Xil_Out32(GPIO_SW_LED_BASEADDR + XGPIO_GIE_OFFSET, XGPIO_GIE_GINTR_ENABLE_MASK);

    XIntc_RegisterHandler(INTC_BASEADDR,
                          XPAR_AXI_INTC_0_AXI_TIMER_0_INTERRUPT_INTR,
                          TimerInterruptHandler,
                          0);
    XIntc_RegisterHandler(INTC_BASEADDR,
                          XPAR_AXI_INTC_0_AXI_GPIO_2_IP2INTC_IRPT_INTR,
                          ButtonInterruptHandler,
                          0);
    XIntc_RegisterHandler(INTC_BASEADDR,
                          XPAR_AXI_INTC_0_AXI_GPIO_0_IP2INTC_IRPT_INTR,
                          SwitchInterruptHandler,
                          0);
    XIntc_EnableIntr(INTC_BASEADDR, INTC_ENABLE_MASK);
    XIntc_MasterEnable(INTC_BASEADDR);
    microblaze_register_handler((XInterruptHandler)XIntc_DeviceInterruptHandler,
                                (void *)XPAR_AXI_INTC_0_DEVICE_ID);
    microblaze_enable_interrupts();
}

u8 PopTimerTick(void)
{
    u8 has_tick;
    microblaze_disable_interrupts();
    has_tick = (TimerTicksPending != 0U);
    if (has_tick) {
        --TimerTicksPending;
    }
    microblaze_enable_interrupts();
    return has_tick;
}

u8 PopButtonEvents(void)
{
    u8 pressed;
    microblaze_disable_interrupts();
    pressed = ButtonPressedEvents;
    ButtonPressedEvents = 0U;
    microblaze_enable_interrupts();
    return pressed;
}

u8 PopSwitchEvent(void)
{
    u8 pending;
    microblaze_disable_interrupts();
    pending = SwitchEventPending;
    SwitchEventPending = 0U;
    microblaze_enable_interrupts();
    return pending;
}
