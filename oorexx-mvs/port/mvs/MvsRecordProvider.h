#ifndef OOREXX_MVS_RECORD_PROVIDER_H
#define OOREXX_MVS_RECORD_PROVIDER_H
/*
 * Explicit logical-record boundary.  NOT a stdio/Unix file emulation.
 * Uses the existing RecordSet C API, at least v0.1-dev11 for retryable CLOSE.
 * No QSAM, DCB, JFCB or SVC-99 internals belong in the interpreter.
 * Initialize a channel only once, on fresh storage. Re-initializing an open
 * or CLOSE_PENDING channel discards the only handle capable of cleanup.
 * This bootstrap is not reentrant or safe to share across concurrent tasks.
 */
#include "RecordSetNative.h"

#ifdef __cplusplus
extern "C" {
#endif

enum RxMvsRecordResult
{
    RX_MVS_RECORD_OK = 0,
    RX_MVS_RECORD_EOF = 1,
    RX_MVS_RECORD_ERROR = 2,
    /* Not a failure: RecordSet/driver cannot determine the value. */
    RX_MVS_RECORD_UNKNOWN = 3
};

enum RxMvsRecordChannelState
{
    RX_MVS_CHANNEL_CLOSED = 0,
    RX_MVS_CHANNEL_OPEN = 1,
    RX_MVS_CHANNEL_CLOSE_PENDING = 2
};

typedef struct RxMvsRecordChannel
{
    RecordSetHandle *backend;
    int closePending;
} RxMvsRecordChannel;

void rx_mvs_record_init(RxMvsRecordChannel *channel);
/* This is CHANNEL state, distinct from DD ownership/allocation metadata.
 * In particular caller-owned DDs can still have QSAM CLOSE pending.
 */
int rx_mvs_record_channel_state(const RxMvsRecordChannel *channel);

int rx_mvs_record_open(RxMvsRecordChannel *channel, const char *resource,
                       int mode, char *error, rs_size_t capacity);
int rx_mvs_record_read(RxMvsRecordChannel *channel,
                       unsigned char **record, rs_size_t *length,
                       char *error, rs_size_t capacity);
int rx_mvs_record_write(RxMvsRecordChannel *channel,
                        const unsigned char *record, rs_size_t length,
                        char *error, rs_size_t capacity);
int rx_mvs_record_close(RxMvsRecordChannel *channel,
                        char *error, rs_size_t capacity);

/* All positions are ONE-BASED LOGICAL RECORD positions, never byte offsets.
 * Positioning may require rewind + sequential reads and can fail partway
 * through; use rx_mvs_record_number() to inspect the resulting cursor.
 * UNKNOWN from count means unsupported/undeterminable, NOT EOF or zero.
 */
int rx_mvs_record_position(RxMvsRecordChannel *channel, rs_size_t oneBasedRecord,
                           char *error, rs_size_t capacity);
int rx_mvs_record_number(const RxMvsRecordChannel *channel, rs_size_t *number,
                         char *error, rs_size_t capacity);
int rx_mvs_record_count(const RxMvsRecordChannel *channel, rs_size_t *count,
                        char *error, rs_size_t capacity);

/* Exactly the RecordSet metadata vocabulary.  In close-pending state only
 * allocation lifecycle metadata is queryable; no logical record I/O.
 * The required result length excludes the terminating NUL.
 */
int rx_mvs_record_text_metadata(const RxMvsRecordChannel *channel, int key,
                                 char *value, rs_size_t valueCapacity,
                                 rs_size_t *required, char *error,
                                 rs_size_t errorCapacity);
int rx_mvs_record_number_metadata(const RxMvsRecordChannel *channel, int key,
                                   rs_size_t *value, char *error,
                                   rs_size_t capacity);

/* rs_read_record returns individually owned payloads. */
void rx_mvs_record_free(void *record);

#ifdef __cplusplus
}
#endif
#endif
