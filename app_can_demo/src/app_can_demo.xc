#include <platform.h>
#include <xscope.h>
#include "can.h"
#include "can_utils.h"
#include "can_board_conf.h"

on tile[0]: can_ports p = CAN_TRIANGLE_SLOT_PORTS;
on tile[0]: port shutdown = CAN_RS_TRIANGLE_SLOT_PORT;

/*==========================================================================*/
void application(client interface interface_can_rx can_rx,
                 client interface interface_can_tx can_tx,
                 client interface interface_can_client can_client)
{
  timer t;
  unsigned now, seed = 0x12345678;
  t:> now;

  while(1)
  {
    can_frame f;
    int done = 0;

    can_utils_make_random_frame(f, seed);

    can_tx.can_frame_send(f);
    can_utils_print_frame(f, "tx: ");

    while(!done)
    {
      select
      {
        //wait for half a second
        case t when timerafter (now + 50000000) :> now:
        {
          done = 1;
          break;
        }

        //or report any frames received
        case can_rx.can_rx_frame_ready():
        {
          can_rx.can_rx_frame(f);
          can_utils_print_frame(f, "rx: ");
          break;
        }

      }//select
    }//while(!done)
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
  interface interface_can_rx can_rx;
  interface interface_can_tx can_tx;
  interface interface_can_client can_client;

  par
  {
    on tile[0]: application(can_rx, can_tx, can_client);
    on tile[0]:
    {
      shutdown <: 0;
      can_server(p, can_rx, can_tx, can_client);
    }
  }//par
  return 0;
}
/*==========================================================================*/
