#include <xscope.h>
#include <print.h>
#include <platform.h>
#include <timer.h>
#include "can.h"
#include "can_utils.h"
#include "can_board_conf.h"

on tile[1]: can_ports p1 = CAN_SQUARE_SLOT_PORTS;
on tile[1]: port rs1 = CAN_RS_SQUARE_SLOT_PORT;

on tile[1]: can_ports p2 = CAN_CIRCLE_SLOT_PORTS;
on tile[1]: port rs2 = CAN_RS_CIRCLE_SLOT_PORT;

/*==========================================================================*/
void app1(client interface interface_can_rx can_rx1,
          client interface interface_can_tx can_tx1,
          client interface interface_can_client can_client1)
{
  unsigned seed = 0x12345678;
  can_frame f;

  can_utils_make_random_frame(f, seed);
  can_tx1.can_frame_send(f);
  can_utils_print_frame(f, "app 1 tx: ");

  while(1)
  {
    select
    {
      case can_rx1.can_rx_frame_ready():
      {
        delay_seconds(1);
        can_rx1.can_rx_frame(f);
        can_utils_print_frame(f, "app 1 rx: ");
        can_tx1.can_frame_send(f);
        can_utils_print_frame(f, "app 1 tx: ");
        break;
      }
    }//select
  }//while(1)
}

/*==========================================================================*/
void app2(client interface interface_can_rx can_rx2,
          client interface interface_can_tx can_tx2,
          client interface interface_can_client can_client2)
{
  while(1)
  {
    select
    {
      case can_rx2.can_rx_frame_ready():
      {
        can_frame f;
        can_rx2.can_rx_frame(f);
        delay_seconds(1);
        can_utils_print_frame(f, "app 2 rx: ");
        can_tx2.can_frame_send(f);
        can_utils_print_frame(f, "app 2 tx: ");
        break;
      }
    }//select
  }//while(1)
}

/*==========================================================================*/
void xscope_user_init(void)
{
  xscope_register(0, 0, "", 0, "");
  xscope_config_io(XSCOPE_IO_BASIC);
}

/*==========================================================================*/
int main()
{
  interface interface_can_rx can_rx1, can_rx2;
  interface interface_can_tx can_tx1, can_tx2;
  interface interface_can_client can_client1, can_client2;

  par
  {
    on tile[1]: app1(can_rx1, can_tx1, can_client1);
    on tile[1]:
    {
      rs1 <: 0;
      can_server(p1, can_rx1, can_tx1, can_client1);
    }

    on tile[1]: app2(can_rx2, can_tx2, can_client2);
    on tile[1]:
    {
      rs2 <: 0;
      can_server(p2, can_rx2, can_tx2, can_client2);
    }
  }
  return 0;
}
/*==========================================================================*/
