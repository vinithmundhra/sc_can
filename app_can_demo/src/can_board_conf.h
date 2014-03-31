#ifndef CAN_BOARD_CONF_H_
#define CAN_BOARD_CONF_H_

/*
 * XA-SK-ISBUS 1v1 -> XP-SKC-L2 1v2 or XP-SKC-A16 1v0 and square slot of U16.
 *
 * Port mapping of ISBUS sliceCARD connected to L16/A16 core board in
 * different slots. U16 - square slot only.
 *
 * Core board connector Pinouts for CAN is:
 * TX = core board socket 15A
 * RX = core board socket 15B
 * RS = core board socket 6B
 */

// CAN RX and TX ports
#define CAN_TRIANGLE_SLOT_PORTS {XS1_PORT_1L, XS1_PORT_1I, XS1_CLKBLK_1}
#define CAN_STAR_SLOT_PORTS     {XS1_PORT_1F, XS1_PORT_1G, XS1_CLKBLK_1}
#define CAN_CIRCLE_SLOT_PORTS   {XS1_PORT_1L, XS1_PORT_1I, XS1_CLKBLK_1}
#define CAN_SQUARE_SLOT_PORTS   {XS1_PORT_1F, XS1_PORT_1G, XS1_CLKBLK_1}

// CAN RS port
#define CAN_RS_TRIANGLE_SLOT_PORT   XS1_PORT_4E
#define CAN_RS_STAR_SLOT_PORT       XS1_PORT_4A
#define CAN_RS_CIRCLE_SLOT_PORT     XS1_PORT_4E
#define CAN_RS_SQUARE_SLOT_PORT     XS1_PORT_4A

// U16 Diamond slot
#define CAN_DIAMOND_SLOT_PORTS    {XS1_PORT_1L, XS1_PORT_1I, XS1_CLKBLK_1}
#define CAN_RS_DIAMOND_SLOT_PORT  XS1_PORT_32A

#endif //CAN_BOARD_CONF_H_
