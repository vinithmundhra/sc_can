#ifndef CAN_H_
#define CAN_H_

#include <xs1.h>

//CAN status defines
#define CAN_STATE_ACTIVE          (0)
#define CAN_STATE_PASSIVE         (1)
#define CAN_STATE_BUS_OFF         (2)

//Return values
#define CAN_FILTER_ADD_SUCCESS    (0)
#define CAN_FILTER_ADD_FAIL       (1)

#define CAN_FILTER_REMOVE_SUCCESS (0)
#define CAN_FILTER_REMOVE_FAIL    (1)

#define CAN_TX_SUCCESS            (0)
#define CAN_TX_FAIL               (1)

#define CAN_RX_SUCCESS            (0)
#define CAN_RX_FAIL               (1)

typedef struct can_frame {
  unsigned remote;   //true for remote
  unsigned extended; //true for extended
  unsigned id;
  unsigned dlc;
  char data[8];
} can_frame;

#ifdef __XC__
typedef struct can_ports {
  out port tx;
  in buffered port:32 rx;
  clock cb;
} can_ports;
#endif

typedef enum {
  TX_FRAME        = 0,
  TX_FRAME_NB     = 1,
  ADD_FILTER      = 2,
  REMOVE_FILTER   = 3,
  GET_STATUS      = 4,
  RESET           = 5,
  PEEK_LATEST     = 6,
  RX_BUF_ENTRIES  = 7,
  RX_FRAME        = 8
} CAN_COMMANDS;

#ifdef __XC__
typedef interface interface_can_rx {
  [[notification]] slave void data_ready();
  [[clears_notification]] unsigned int data_get(can_frame &frm);
  unsigned int has_data();
  unsigned int get_err_count();
}interface_can_rx;

typedef interface interface_can_tx {
  [[notification]] slave void data_sent();
  [[clears_notification]] unsigned int data_put(can_frame &frm);
  unsigned int has_data();
  unsigned int get_err_count();
}interface_can_tx;

typedef interface interface_can_client {
  void reset();
  unsigned get_status();
  unsigned add_filter(unsigned id);
  unsigned remove_filter(unsigned id);
}interface_can_client;

void can_server(can_ports &p,
                server interface interface_can_rx i_rx,
                server interface interface_can_tx i_tx,
                server interface interface_can_client i_client);
#endif

#endif /* CAN_H_ */
