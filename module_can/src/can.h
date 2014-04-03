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
  /**
   * This is a notification event. It notifies that a CAN frame is received
   * and is waiting in the RX buffer. Call ``can_rx_frame`` to get the frame.
   */
  [[notification]] slave void can_rx_frame_ready();

  /**
   * Take the oldest frame from the RX buffer. If the buffer is empty it will
   * return a (-1) and the frm is invalid. If RX buffer has unread frame(s), it
   * returns the number of frames in the RX buffer (not including currently read
   * frame).
   *
   * \param frm a CAN bus frame passed by reference
   * \return (-1) on buffer underflow. Else, number of unread frames after this
   *         frame.
   */
  [[clears_notification]] unsigned int can_rx_frame(can_frame &frm);

  /**
   * Find the number of frames currently in the RX buffer.
   *
   * \return number of frames in the RX buffer
   */
  unsigned int can_rx_entries();

  /**
   * Number of RX errors. Resets on ``reset()`` command.
   *
   * \return number of RX errors.
   */
  unsigned int can_rx_err_count();

}interface_can_rx;

typedef interface interface_can_tx {

  /**
   * This is a notification event. It notifies that a CAN frame has been
   * successfully sent.
   */
  [[notification]] slave void can_frame_sent();

  /**
   * Put a CAN frame in the TX buffer to send. If the TX buffer is full, it
   * will return a (-1); If the frame is successfully placed in the TX buffer,
   * it reutrns (0). Once the CAN frame is sent, ``can_frame_sent()`` event is
   * triggerred.
   *
   * \param frm a CAN bus frame passed by reference
   * \return (-1) on buffer overflow. (0) on success.
   */
  [[clears_notification]] unsigned int can_frame_send(can_frame &frm);

  /**
   * Number of frames present in the TX buffer.
   *
   * \return number of frames in the TX buffer
   */
  unsigned int can_tx_entries();

  /**
   * Number of transmit errors. Resets on ``reset()`` command.
   *
   * \return number of transmit errors.
   */
  unsigned int can_tx_err_count();

}interface_can_tx;

typedef interface interface_can_client {

  /**
   * This resets the transciever to the state it would be when first switched
   * on. All error counter are reset, status is set to 'ACTIVE' and the rx/tx
   * buffer is cleared.
   */
  void can_reset();

  /**
   * This returns the status of the CAN Bus server. Can be in state
   * CAN_STATE_ACTIVE, CAN_STATE_PASSIVE or CAN_STATE_BUS_OFF.
   *
   * \return The state of the server.
   */
  unsigned can_get_status();

  /**
   * This adds a filter to the CAN transiever. The filter will reject any
   * frames with id's matching any of its entries.
   *
   * \param id The id to be added to the frame filter.
   * \return CAN_FILTER_ADD_SUCCESS or CAN_FILTER_ADD_FAIL.
   */
  unsigned can_add_filter(unsigned id);

  /**
   * This removes a filter from the CAN transiever.
   *
   * \param id The id to be removed from the frame filter.
   * \return CAN_FILTER_REMOVE_SUCCESS or CAN_FILTER_REMOVE_FAIL.
   */
  unsigned can_remove_filter(unsigned id);

  /**
   * This removes all filters from the CAN transiever.
   *
   * \return CAN_FILTER_REMOVE_SUCCESS or CAN_FILTER_REMOVE_FAIL.
   */
  unsigned can_remove_all_filters();

}interface_can_client;

void can_server(can_ports &p,
                server interface interface_can_rx i_rx,
                server interface interface_can_tx i_tx,
                server interface interface_can_client i_client);
#endif

#endif /* CAN_H_ */
