#include "can.h"
#include "can_defines.h"
#include "can_config.h"
#include <xclib.h>
#include <string.h>

typedef struct RxTxFrame {
  unsigned rx_DATA[2];
  unsigned tx_DATA[2];
  //These are all word aligned as they are accessed via the dp
  unsigned rx_remote; //true for remote
  unsigned tx_remote; //true for remote
  unsigned rx_extended; //true for extended
  unsigned tx_extended; //true for extended
  unsigned rx_id_std;
  unsigned tx_id_std;
  unsigned rx_id_ext;
  unsigned tx_id_ext;
  unsigned rx_dlc;
  unsigned tx_dlc;
} RxTxFrame;

extern int canRxTxImpl(unsigned tx,
                       unsigned time,
                       struct can_ports &p,
                       RxTxFrame &rx_tx_frame,
                       unsigned error_status);

/*============================================================================*/
#pragma unsafe arrays
static inline void zeroFrame(RxTxFrame &f)
{
  f.rx_DATA[0] = 0; f.rx_DATA[1] = 0;
  f.tx_DATA[0] = 0; f.tx_DATA[1] = 0;
  f.rx_remote = 0; f.tx_remote = 0;
  f.rx_extended = 0; f.tx_extended = 0;
  f.rx_id_std = 0; f.tx_id_std = 0;
  f.rx_id_ext = 0; f.tx_id_ext = 0;
  f.rx_dlc = 0; f.tx_dlc = 0;
}
/*============================================================================*/
static void init(struct can_ports &p)
{
  stop_clock(p.cb);
  set_clock_div(p.cb, CAN_CLOCK_DIVIDE);
  set_port_clock(p.tx, p.cb);
  set_port_clock(p.rx, p.cb);
  start_clock(p.cb);
}
/*============================================================================*/
//Takes a non-mangled RxTxFrame and mangles it(for the reciever)
#pragma unsafe arrays
static inline void mangle_data(RxTxFrame &f)
{
  unsigned t = byterev(bitrev(f.tx_DATA[0]));
  unsigned p = byterev(bitrev(f.tx_DATA[1]));
  unsigned dlc = f.tx_dlc;
  f.tx_dlc = (bitrev(dlc) >> 28) & 0xf;
  switch (dlc)
  {
    case 0: return;
    case 1:
    case 2:
    case 3:
    case 4: f.tx_DATA[1] = t; break;
    case 5: f.tx_DATA[0] = t&0xff; f.tx_DATA[1] = (p<<24) | (t>>8); break;
    case 6: f.tx_DATA[0] = t&0xffff; f.tx_DATA[1] = (p<<16) + (t>>16); break;
    case 7: f.tx_DATA[0] = t&0xffffff; f.tx_DATA[1] = (p<<8) + (t>>24); break;
    case 8: f.tx_DATA[0] = t; f.tx_DATA[1] = p; break;
  }//switch (dlc)
}
/*============================================================================*/
//Takes a mangled(out of the reciever) RxTxFrame and demangles it.
//Note, mangle and demangle are not symetric.
#pragma unsafe arrays
static inline void demangle_data(RxTxFrame &f)
{
  unsigned t = byterev(f.rx_DATA[0]);
  unsigned p = byterev(f.rx_DATA[1]);
  switch (f.rx_dlc)
  {
    case 0: return;
    case 1: f.rx_DATA[0] = p>>24; break;
    case 2: f.rx_DATA[0] = p>>16; break;
    case 3: f.rx_DATA[0] = p>>8; break;
    case 4: f.rx_DATA[0] = p; break;
    case 5: f.rx_DATA[0] = (t>>24) + (p<<8); f.rx_DATA[1] = (p>>24)&0xff; break;
    case 6: f.rx_DATA[0] = (t>>16) + (p<<16); f.rx_DATA[1] = (p>>16)&0xffff; break;
    case 7: f.rx_DATA[0] = (t>>8) + (p<<24); f.rx_DATA[1] = (p>>8)&0xffffff; break;
    case 8: f.rx_DATA[0] = t; f.rx_DATA[1] = p; break;
  }//switch (f.rx_dlc)
}
/*============================================================================*/
#pragma unsafe arrays
static inline void frame_to_rxtx(can_frame &f, RxTxFrame &r)
{
  unsigned id = bitrev(f.id);
  if (f.extended)
  {
    r.tx_id_std = (id >> 3) & 0x7ff;
    r.tx_id_ext = (id >> 14) & 0x3ffff;
  }
  else
  {
    r.tx_id_std = (id >> 21) & 0x7ff;
    r.tx_id_ext = 0;
  }
  r.tx_extended = f.extended;
  r.tx_remote = f.remote;
  r.tx_dlc = f.dlc;
  r.tx_DATA[0] = (f.data, unsigned[])[0];
  r.tx_DATA[1] = (f.data, unsigned[])[1];
}
/*============================================================================*/
#pragma unsafe arrays
static inline void rxtx_to_frame(can_frame &f, RxTxFrame &r)
{
  f.extended = r.rx_extended;
  f.dlc = r.rx_dlc;
  f.remote = r.rx_remote;
  if (f.extended)
  {
    f.id = (r.rx_id_std << 18) | r.rx_id_ext;
  }
  else
  {
    f.id = r.rx_id_std;
  }
  (f.data, unsigned[])[0] = r.rx_DATA[0];
  (f.data, unsigned[])[1] = r.rx_DATA[1];
}
/*============================================================================*/
static void adjust_successful_receive_error_counter(unsigned &receive_error_counter)
{
  if (receive_error_counter > 0)
  {
    if (receive_error_counter < 128) receive_error_counter--;
    else receive_error_counter = 127;
  }
}
/*============================================================================*/
//This is far from the spec and could do with a lot of improvement
static void send_active_error(struct can_ports &p)
{
  unsigned error_start;
  unsigned release_flag;
  p.tx <: 0 @ error_start;
  error_start += 50 * 6;
  p.tx <: 1 @ error_start;
  p.rx when pinseq(1) :> unsigned @ release_flag;
}
/*============================================================================*/
static void adjust_status(unsigned &error_status,
                          unsigned transmit_error_counter,
                          unsigned receive_error_counter,
                          struct can_ports &p)
{

  if (transmit_error_counter > 127)
  {
    if (transmit_error_counter > 255)
    {
      error_status = CAN_STATE_BUS_OFF;
    }
    else
    {
      error_status = CAN_STATE_PASSIVE;
      send_active_error(p);
    }
  }
  else if(receive_error_counter > 127)
  {
    error_status = CAN_STATE_PASSIVE;
    send_active_error(p);
  }
  else
  {
    error_status = CAN_STATE_ACTIVE;
  }
}
/*============================================================================*/
#pragma unsafe arrays
static int reject_message(unsigned message_filters[CAN_MAX_FILTER_SIZE],
                          unsigned message_filter_count,
                          unsigned id)
{
  for (unsigned i = 0; i < message_filter_count; i++)
  {
    if (message_filters[i] == id) return 1;
  }
  return 0;
}
/*============================================================================*/
static int rx_success(RxTxFrame &r,
                      can_frame rx_buf[],
                      unsigned int &rd,
                      unsigned int &wr,
                      unsigned int &dep,
                      unsigned message_filters[],
                      unsigned message_filter_count,
                      unsigned &rx_err_count)
{
  if(dep >= CAN_FRAME_BUFFER_SIZE)
  {
    //handle buffer overflow
    return -1;
  }

  demangle_data(r);
  rxtx_to_frame(rx_buf[wr], r);
  adjust_successful_receive_error_counter(rx_err_count);

  if (CAN_MAX_FILTER_SIZE)
  {
    if (!reject_message(message_filters,
                        message_filter_count,
                        rx_buf[wr].id))
    {
      wr = (wr + 1) % CAN_FRAME_BUFFER_SIZE;
      dep++;
      return CAN_RX_SUCCESS;
    }
    return CAN_RX_FAIL;
  }
  else
  {
    wr = (wr + 1) % CAN_FRAME_BUFFER_SIZE;
    dep++;
    return CAN_RX_SUCCESS;
  }
}
/*============================================================================*/
#pragma unsafe arrays
void can_server(can_ports &p,
                server interface interface_can_rx i_rx,
                server interface interface_can_tx i_tx,
                server interface interface_can_client i_client)
{
  can_frame rx_buf[CAN_FRAME_BUFFER_SIZE];
  can_frame tx_buf[CAN_FRAME_BUFFER_SIZE];

  RxTxFrame r;

  unsigned int rx_fifo_read = 0, rx_fifo_write = 0;
  unsigned int tx_fifo_read = 0, tx_fifo_write = 0;
  unsigned int rx_depth = 0, tx_depth = 0;

  unsigned error_status = CAN_STATE_ACTIVE;
  unsigned int rx_err_count = 0, tx_err_count = 0;

  unsigned message_filters[CAN_MAX_FILTER_SIZE];
  unsigned message_filter_count = 0;

  unsigned tx_enabled = 1;
  unsigned tx_back_on;

  unsigned time;
  timer bit_timer;

  init(p);
  zeroFrame(r);

  while(1)
  {
    select
    {
      /*
       * ---------------------------------------------------------------------
       * RECEIVE
       * ---------------------------------------------------------------------
       */
      case p.rx when pinseq(error_status == CAN_STATE_BUS_OFF) :> int @ time:
      {
        if(error_status == CAN_STATE_BUS_OFF)
        {
#pragma xta label "bus_off"
          unsigned val;
          timer t;
          unsigned time;
          t :> time;
          select
          {
            case p.rx when pinseq(0) :> unsigned: break;
            case t when timerafter(time + 128*11*CAN_CLOCK_DIVIDE*100) :> time:
            {
              error_status = CAN_STATE_ACTIVE;
              tx_err_count = 0;
              rx_err_count = 0;
              break;
            } //case t when timerafter(time + 128*11*CAN_CLOCK_DIVIDE*100) :> time:
          } //select
        } //if(error_status == CAN_STATE_BUS_OFF)
        else
        {
          int e = canRxTxImpl(0, time, p, r, error_status);
          bit_timer :> tx_back_on;
          tx_back_on += 3*CAN_CLOCK_DIVIDE*2*50;
          tx_enabled = 0;
          if (RXTX_RET_TO_ERROR_TYPE(e) == CAN_ERROR_RX_NONE)
          {
            int rx_succ = rx_success(r,
                                     rx_buf,
                                     rx_fifo_read,
                                     rx_fifo_write,
                                     rx_depth,
                                     message_filters,
                                     message_filter_count,
                                     rx_err_count);

            if(rx_succ == CAN_RX_SUCCESS)
            {
              i_rx.data_ready();
            }
          } //if (RXTX_RET_TO_ERROR_TYPE(e) == CAN_ERROR_RX_NONE)
          else
          {
            rx_err_count += RXTX_RET_TO_ERROR_COUNTER(e);
          } //else
          zeroFrame(r);
          break;
        } //else

        break;
      }//case p.rx when pinseq(error_status == CAN_STATE_BUS_OFF) :> int @ time:

      /*=====================================================================*/

      case i_rx.data_get(can_frame &frm) -> unsigned int err:
      {
        if (rx_depth <= 0)
        {
          // handle buffer underflow
          err = -1;
          continue;
        }

        memcpy(&frm, &rx_buf[rx_fifo_read], sizeof(can_frame));
        rx_fifo_read = (rx_fifo_read + 1) % CAN_FRAME_BUFFER_SIZE;
        rx_depth--;
        if (rx_depth) i_rx.data_ready();
        err = 0;

        break;
      }//case i_rx.data_get(can_frame &frm) -> unsigned int err:

      /*=====================================================================*/

      case i_rx.has_data() -> unsigned int depth:
      {
        depth = rx_depth;
        break;
      }//case i_rx.has_data() -> unsigned int depth:

      /*=====================================================================*/

      case i_rx.get_err_count() -> unsigned int count:
      {
        count = rx_err_count;
        break;
      }//case i_rx.get_err_count() -> unsigned int count:

      /*=====================================================================*/

      /*
       * ---------------------------------------------------------------------
       * TX ENABLE TIMER
       * ---------------------------------------------------------------------
       */

      case !tx_enabled => bit_timer when timerafter(tx_back_on) :> int:
      {
        tx_enabled = 1;
        break;
      }//case !tx_enabled => bit_timer when timerafter(tx_back_on) :> int:

      /*
       * ---------------------------------------------------------------------
       * TRANSMIT
       * ---------------------------------------------------------------------
       */

      case i_tx.data_put(can_frame &frm) -> unsigned int err:
      {
        int e = 0;
        err = 0;
        if(error_status == CAN_STATE_BUS_OFF)
        {
          err = -1;
          continue;
        }

        if(tx_depth >= CAN_FRAME_BUFFER_SIZE)
        {
          // handle buffer overflow
          err = -1;
          continue;
        }

        memcpy(&tx_buf[tx_fifo_write], &frm, sizeof(can_frame));
        frame_to_rxtx(tx_buf[tx_fifo_write], r);
        mangle_data(r);
        tx_fifo_write = (tx_fifo_write + 1) % CAN_FRAME_BUFFER_SIZE;
        tx_depth++;

        if(tx_enabled)
        {
          e = canRxTxImpl(1, 0, p, r, error_status);
          bit_timer :> tx_back_on;
        }//if(tx_enabled)
        else
        {
          select
          {
            case p.rx when pinseq(0) :> int @ time:
            {
              e = canRxTxImpl(0, time, p, r, error_status);
              bit_timer :> tx_back_on;
              break;
            }
            case bit_timer when timerafter(tx_back_on) :> int :
            {
              e = canRxTxImpl(1, 0, p, r, error_status);
              bit_timer :> tx_back_on;
              break;
            }
          }//select
        }//else

        tx_back_on += 3*CAN_CLOCK_DIVIDE*2*50;
        tx_enabled = 0;

        if(RXTX_RET_TO_ERROR_TYPE(e) == CAN_ERROR_TX_NONE)
        {
          tx_depth--;
          if(tx_err_count)
            tx_err_count--;
          if(error_status == CAN_STATE_PASSIVE)
            tx_back_on += 8*CAN_CLOCK_DIVIDE*2*50;
          i_tx.data_sent();
          break;
        }//if CAN_ERROR_TX_NONE:
        else
        {
          tx_err_count += RXTX_RET_TO_ERROR_COUNTER(e);
          if(error_status == CAN_STATE_PASSIVE)
            tx_back_on += 8*CAN_CLOCK_DIVIDE*2*50;
          break;
        }//else

        zeroFrame(r);
        adjust_status(error_status, tx_err_count, rx_err_count, p);
        break;
      }//case i_tx.data_put(can_frame &frm) -> unsigned int err:

      /*=====================================================================*/

      case i_tx.has_data() -> unsigned int depth:
      {
        depth = tx_depth;
        break;
      }//case i_tx.has_data() -> unsigned int depth:

      /*=====================================================================*/

      case i_tx.get_err_count() -> unsigned int count:
      {
        count = tx_err_count;
        break;
      }//case i_tx.get_err_count() -> unsigned int count:

      /*=====================================================================*/

      /*
       * ---------------------------------------------------------------------
       * CLIENT
       * ---------------------------------------------------------------------
       */

      case i_client.reset():
      {
        error_status = CAN_STATE_ACTIVE;
        rx_fifo_read = 0; rx_fifo_write = 0;
        tx_fifo_read = 0; tx_fifo_write = 0;

        rx_err_count = 0; tx_err_count = 0;
        rx_depth = 0; tx_depth = 0;

        message_filter_count=0;
        tx_enabled = 1;

        break;
      }//case i_client.reset():

      /*=====================================================================*/

      case i_client.get_status() -> unsigned status:
      {
        status = error_status;
        break;
      }//case i_client.get_status() -> unsigned status:

      /*=====================================================================*/

      case i_client.add_filter(unsigned id) -> unsigned result:
      {
        if(message_filter_count < CAN_MAX_FILTER_SIZE)
        {
          message_filters[message_filter_count] = id;
          message_filter_count++;
          result = CAN_FILTER_ADD_SUCCESS;
        }
        else
        {
          result = CAN_FILTER_ADD_FAIL;
        }
        break;
      }//case i_client.add_filter(unsigned id) -> unsigned result:

      /*=====================================================================*/

      case i_client.remove_filter(unsigned id) -> unsigned result:
      {
        unsigned index=0;
        unsigned found=0;

        for(index = 0; index < message_filter_count; index++)
        {
          if(message_filters[index] == id)
          {
            found = 1;
            break;
          }
        }

        if(found)
        {
          for(unsigned i = index; i < message_filter_count; i++)
          {
            if((i + 1) < CAN_MAX_FILTER_SIZE)
              message_filters[i] = message_filters[i+1];
          }
          message_filter_count--;
          result = CAN_FILTER_REMOVE_SUCCESS;
        }
        else
        {
          result = CAN_FILTER_REMOVE_FAIL;
        }
        break;
      }//case i_client.remove_filter(unsigned id) -> unsigned result:

      /*=====================================================================*/

    }//select
  }//while(1)
}
