/*
 * SRT - Secure, Reliable, Transport
 * Copyright (c) 2018 Haivision Systems Inc.
 * 
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 */

/*****************************************************************************
written by
   Haivision Systems Inc.
 *****************************************************************************/

#ifndef INC_SRT_VERSION_H
#define INC_SRT_VERSION_H

// To construct version value
#define SRT_MAKE_VERSION(major, minor, patch) \
   ((patch) + ((minor)*0x100) + ((major)*0x10000))
#define SRT_MAKE_VERSION_VALUE SRT_MAKE_VERSION

#define SRT_VERSION_MAJOR 1
#define SRT_VERSION_MINOR 5
#define SRT_VERSION_PATCH 3
/* #undef SRT_VERSION_BUILD */

#define SRT_VERSION_STRING "1.5.3"
#define SRT_VERSION_VALUE \
   SRT_MAKE_VERSION_VALUE( \
      SRT_VERSION_MAJOR, SRT_VERSION_MINOR, SRT_VERSION_PATCH )

#endif // INC_SRT_VERSION_H
