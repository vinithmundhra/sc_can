#ifndef CAN_CONFIG_H_
#define CAN_CONFIG_H_

#ifdef __can_conf_h_exists__
#include "can_conf.h"
#endif

#ifndef CAN_FRAME_BUFFER_SIZE
#define CAN_FRAME_BUFFER_SIZE 16
#endif

#ifndef CAN_MAX_FILTER_SIZE
#define CAN_MAX_FILTER_SIZE 4
#endif

#ifndef CAN_CLOCK_DIVIDE
#define CAN_CLOCK_DIVIDE 2
#endif

#ifndef PROP_SEG
  #define PROP_SEG 8
#else
  #if (PROP_SEG > 8)
    #error PROP_SEG must be from 1 to 8 TIME QUANTUM long.
  #endif
#endif

#ifndef PHASE_SEG1
  #define PHASE_SEG1 8
#else
  #if (PHASE_SEG1 > 8)
    #error PHASE_SEG1 must be from 1 to 8 TIME QUANTUM long.
  #endif
#endif

#ifndef PHASE_SEG2
  #define PHASE_SEG2 8
#else
  #if (PHASE_SEG2 < PHASE_SEG1)
    #error PHASE_SEG2 not be shorter then PHASE_SEG1.
  #endif
#endif

#endif /*CAN_CONFIG_H_*/
