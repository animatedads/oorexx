#include "MvsRecordProvider.h"

/* Error handling must not assume a particular C runtime charset. */
static int invalid(char *error, rs_size_t capacity, const char *message)
{
    rs_size_t i;
    if (error != 0 && capacity != 0)
    {
        i = 0;
        while (i + 1 < capacity && message[i] != '\0')
        {
            error[i] = message[i];
            ++i;
        }
        error[i] = '\0';
    }
    return RX_MVS_RECORD_ERROR;
}

void rx_mvs_record_init(RxMvsRecordChannel *channel)
{
    if (channel != 0)
    {
        channel->backend = 0;
        channel->closePending = 0;
    }
}

int rx_mvs_record_channel_state(const RxMvsRecordChannel *channel)
{
    if (channel == 0 || channel->backend == 0) return RX_MVS_CHANNEL_CLOSED;
    return channel->closePending ? RX_MVS_CHANNEL_CLOSE_PENDING : RX_MVS_CHANNEL_OPEN;
}

int rx_mvs_record_open(RxMvsRecordChannel *channel, const char *resource,
                       int mode, char *error, rs_size_t capacity)
{
    int rc;
    if (channel == 0) return invalid(error, capacity, "Missing MVS record channel");
    if (channel->backend != 0) return invalid(error, capacity, "Record channel already has an owned handle");
    if (resource == 0 || resource[0] == '\0') return invalid(error, capacity, "Missing MVS record resource");
    /* The provider validates DD:, MVS dataset, and dataset(member) names.
     * Never reinterpret a Unix pathname as a dataset or invented byte stream. */
    rc = rs_open(resource, mode, &channel->backend, error, capacity);
    if (rc != RS_STATUS_OK)
    {
        channel->backend = 0;
        return RX_MVS_RECORD_ERROR;
    }
    channel->closePending = 0;
    return RX_MVS_RECORD_OK;
}

int rx_mvs_record_read(RxMvsRecordChannel *channel,
                       unsigned char **record, rs_size_t *length,
                       char *error, rs_size_t capacity)
{
    int rc;
    if (record != 0) *record = 0;
    if (length != 0) *length = 0;
    if (channel == 0 || channel->backend == 0 || channel->closePending)
        return invalid(error, capacity, "MVS record channel is not open for reading");
    if (record == 0 || length == 0)
        return invalid(error, capacity, "Reading a record requires data and length outputs");
    rc = rs_read_record(channel->backend, record, length, error, capacity);
    if (rc == RS_STATUS_OK) return RX_MVS_RECORD_OK;
    if (rc == RS_STATUS_EOF) return RX_MVS_RECORD_EOF;
    return RX_MVS_RECORD_ERROR;
}

int rx_mvs_record_write(RxMvsRecordChannel *channel,
                        const unsigned char *record, rs_size_t length,
                        char *error, rs_size_t capacity)
{
    if (channel == 0 || channel->backend == 0 || channel->closePending)
        return invalid(error, capacity, "MVS record channel is not open for writing");
    return rs_write_record(channel->backend, record, length, error, capacity)
            == RS_STATUS_OK ? RX_MVS_RECORD_OK : RX_MVS_RECORD_ERROR;
}

int rx_mvs_record_close(RxMvsRecordChannel *channel,
                        char *error, rs_size_t capacity)
{
    if (channel == 0) return invalid(error, capacity, "Missing MVS record channel");
    if (channel->backend == 0) return RX_MVS_RECORD_OK;
    /* dev11 guarantees the handle remains valid after failed QSAM CLOSE or
     * allocation release, and retries only whichever cleanup step is due.
     * Do not destroy the only token that can retry SVC-99 unallocation. */
    if (rs_close_status(channel->backend, error, capacity) != RS_STATUS_OK)
    {
        channel->closePending = 1;
        return RX_MVS_RECORD_ERROR;
    }
    channel->backend = 0;
    channel->closePending = 0;
    return RX_MVS_RECORD_OK;
}

void rx_mvs_record_free(void *record) { rs_free_record(record); }

/* Logical-record API only. No SEEK, byte offsets, or synthetic LF records. */
int rx_mvs_record_position(RxMvsRecordChannel *channel, rs_size_t oneBasedRecord,
                           char *error, rs_size_t capacity)
{
    if (channel == 0 || channel->backend == 0 || channel->closePending)
        return invalid(error, capacity, "Cannot position an inactive MVS record channel");
    if (oneBasedRecord == 0)
        return invalid(error, capacity, "MVS record positions are one-based");
    return rs_position_record(channel->backend, oneBasedRecord, error, capacity)
            == RS_STATUS_OK ? RX_MVS_RECORD_OK : RX_MVS_RECORD_ERROR;
}

int rx_mvs_record_number(const RxMvsRecordChannel *channel, rs_size_t *number,
                         char *error, rs_size_t capacity)
{
    if (number != 0) *number = 0;
    if (channel == 0 || channel->backend == 0 || channel->closePending || number == 0)
        return invalid(error, capacity, "Cannot query inactive MVS record position");
    *number = rs_record_number(channel->backend);
    return RX_MVS_RECORD_OK;
}

int rx_mvs_record_count(const RxMvsRecordChannel *channel, rs_size_t *count,
                        char *error, rs_size_t capacity)
{
    int rc;
    if (count != 0) *count = 0;
    if (channel == 0 || channel->backend == 0 || channel->closePending || count == 0)
        return invalid(error, capacity, "Cannot count an inactive MVS record channel");
    rc = rs_record_count(channel->backend, count, error, capacity);
    if (rc == RS_STATUS_OK) return RX_MVS_RECORD_OK;
    if (rc == RS_STATUS_UNKNOWN) { *count = 0; return RX_MVS_RECORD_UNKNOWN; }
    *count = 0;
    return RX_MVS_RECORD_ERROR;
}

static int valid_text_meta(int key)
{
    return key == RS_META_NAME || key == RS_META_DD_NAME ||
           key == RS_META_DATASET_NAME || key == RS_META_MEMBER_NAME ||
           key == RS_META_ORGANIZATION || key == RS_META_RECORD_FORMAT ||
           key == RS_META_ALLOCATION_STATE;
}

int rx_mvs_record_text_metadata(const RxMvsRecordChannel *channel, int key,
                                 char *value, rs_size_t valueCapacity,
                                 rs_size_t *required, char *error,
                                 rs_size_t errorCapacity)
{
    int rc;
    if (required != 0) *required = 0;
    if (value != 0 && valueCapacity != 0) value[0] = '\0';
    if (channel == 0 || channel->backend == 0)
        return invalid(error, errorCapacity, "Cannot query unopened MVS record channel");
    if (!valid_text_meta(key))
        return invalid(error, errorCapacity, "Unknown MVS record text metadata key");
    if (channel->closePending && key != RS_META_ALLOCATION_STATE)
        return invalid(error, errorCapacity, "Only allocation state is queryable during MVS cleanup");
    rc = rs_text_metadata(channel->backend, key, value, valueCapacity, required);
    if (rc == RS_STATUS_OK) return RX_MVS_RECORD_OK;
    if (rc == RS_STATUS_UNKNOWN)
    {
        if (required != 0) *required = 0;
        if (value != 0 && valueCapacity != 0) value[0] = '\0';
        return RX_MVS_RECORD_UNKNOWN;
    }
    if (required != 0) *required = 0;
    if (value != 0 && valueCapacity != 0) value[0] = '\0';
    return invalid(error, errorCapacity, "MVS record text metadata query failed");
}

int rx_mvs_record_number_metadata(const RxMvsRecordChannel *channel, int key,
                                   rs_size_t *value, char *error,
                                   rs_size_t capacity)
{
    int rc;
    if (value != 0) *value = 0;
    if (channel == 0 || channel->backend == 0 || channel->closePending || value == 0)
        return invalid(error, capacity, "Cannot query numeric metadata of an inactive MVS record channel");
    if (key != RS_META_LRECL && key != RS_META_BLKSIZE)
        return invalid(error, capacity, "Unknown MVS record numeric metadata key");
    rc = rs_number_metadata(channel->backend, key, value);
    if (rc == RS_STATUS_OK) return RX_MVS_RECORD_OK;
    if (rc == RS_STATUS_UNKNOWN) { *value = 0; return RX_MVS_RECORD_UNKNOWN; }
    *value = 0;
    return invalid(error, capacity, "MVS record numeric metadata query failed");
}
