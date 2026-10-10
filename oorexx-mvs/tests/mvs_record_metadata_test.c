#include <stdio.h>
#include <string.h>
#include "MvsRecordProvider.h"
#include "RecordSetMvsQsam.h"

void dev10_qsam_reset(void);
void fake_dyn_reset(void);
void fake_dyn_fail_unalloc_times(int times);
int fake_dyn_unalloc_calls(void);
void dev10_qsam_read_rc(int rc);
void dev10_qsam_rewind_rc(int rc);
void dev10_qsam_close_rc(int rc);
int dev10_qsam_close_calls(void);

#define REQUIRE(x) do { if (!(x)) { fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #x); return 1; } } while(0)

int main(void)
{
    RxMvsRecordChannel ch;
    rs_size_t value;
    rs_size_t required;
    rs_size_t n;
    char meta[40];
    char err[160];
    unsigned char *record;
    rs_size_t length;

    dev10_qsam_reset();
    rx_mvs_record_init(&ch);
    REQUIRE(rx_mvs_record_channel_state(&ch) == RX_MVS_CHANNEL_CLOSED);
    REQUIRE(rx_mvs_record_channel_state(0) == RX_MVS_CHANNEL_CLOSED);
    value = 123;
    REQUIRE(rx_mvs_record_count(&ch, &value, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(value == 0);
    REQUIRE(rx_mvs_record_number(&ch, &value, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_position(&ch, 1, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_NAME, meta, sizeof(meta),
            &required, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(meta[0] == '\0' && required == 0);
    REQUIRE(rx_mvs_record_open(&ch, "DD:RSIN", RS_MODE_READ, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_channel_state(&ch) == RX_MVS_CHANNEL_OPEN);
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_DD_NAME, meta, sizeof(meta),
            &required, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(strcmp(meta, "RSIN") == 0 && required == 4);
    meta[0] = 'X';
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_ALLOCATION_STATE, meta, 1,
            &required, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(meta[0] == '\0' && required == strlen("CALLER_DD"));
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_ALLOCATION_STATE, meta, sizeof(meta),
            &required, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(strcmp(meta, "CALLER_DD") == 0);
    meta[0] = 'X';
    REQUIRE(rx_mvs_record_text_metadata(&ch, 9999, meta, sizeof(meta),
            &required, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(meta[0] == '\0' && required == 0);
    REQUIRE(rx_mvs_record_number_metadata(&ch, RS_META_LRECL, &value, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(value == 80);
    REQUIRE(rx_mvs_record_number_metadata(&ch, RS_META_BLKSIZE, &value, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(value == 800);
    value = 17;
    REQUIRE(rx_mvs_record_number_metadata(&ch, 999, &value, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(value == 0);
    /* Sequential QSAM cannot answer record count cheaply, so UNKNOWN != EOF. */
    value = 17;
    REQUIRE(rx_mvs_record_count(&ch, &value, err, sizeof(err)) == RX_MVS_RECORD_UNKNOWN);
    REQUIRE(value == 0);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_OK && n == 1);
    REQUIRE(rx_mvs_record_position(&ch, 0, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    dev10_qsam_read_rc(MVSRS_QSAM_OK);
    REQUIRE(rx_mvs_record_read(&ch, &record, &length, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(length == 0 && record != 0);
    rx_mvs_record_free(record);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_OK && n == 2);
    dev10_qsam_rewind_rc(MVSRS_QSAM_ERROR);
    REQUIRE(rx_mvs_record_position(&ch, 1, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_OK && n == 2);
    dev10_qsam_rewind_rc(MVSRS_QSAM_OK);
    REQUIRE(rx_mvs_record_position(&ch, 1, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_position(&ch, 3, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_OK && n == 3);
    dev10_qsam_read_rc(MVSRS_QSAM_EOF);
    REQUIRE(rx_mvs_record_position(&ch, 4, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_OK && n == 1);

    /* A failed CLOSE must not erase the only cleanup token. */
    dev10_qsam_close_rc(MVSRS_QSAM_ERROR);
    REQUIRE(rx_mvs_record_close(&ch, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_channel_state(&ch) == RX_MVS_CHANNEL_CLOSE_PENDING);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_position(&ch, 1, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_count(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_DD_NAME, meta, sizeof(meta),
            &required, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_ALLOCATION_STATE, meta, sizeof(meta),
            &required, err, sizeof(err)) == RX_MVS_RECORD_OK);
    /* Caller owned DD does not imply QSAM close is complete. */
    REQUIRE(strcmp(meta, "CALLER_DD") == 0);
    REQUIRE(rx_mvs_record_number_metadata(&ch, RS_META_LRECL, &n, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    dev10_qsam_close_rc(MVSRS_QSAM_OK);
    REQUIRE(rx_mvs_record_close(&ch, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_channel_state(&ch) == RX_MVS_CHANNEL_CLOSED);
    REQUIRE(dev10_qsam_close_calls() == 2);

    /* Owned dataset DD: successful CLOSE followed by failed UNALLOC.
     * Retrying must release the DD WITHOUT re-closing the QSAM handle. */
    fake_dyn_reset();
    dev10_qsam_reset();
    REQUIRE(rx_mvs_record_open(&ch, "'USER.DATA'", RS_MODE_READ, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_ALLOCATION_STATE,
            meta, sizeof(meta), &required, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(strcmp(meta, "OWNED_DD") == 0);
    fake_dyn_fail_unalloc_times(1);
    REQUIRE(rx_mvs_record_close(&ch, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_channel_state(&ch) == RX_MVS_CHANNEL_CLOSE_PENDING);
    REQUIRE(rx_mvs_record_text_metadata(&ch, RS_META_ALLOCATION_STATE,
            meta, sizeof(meta), &required, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(strcmp(meta, "RELEASE_PENDING") == 0);
    REQUIRE(dev10_qsam_close_calls() == 1 && fake_dyn_unalloc_calls() == 1);
    REQUIRE(rx_mvs_record_close(&ch, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_channel_state(&ch) == RX_MVS_CHANNEL_CLOSED);
    REQUIRE(dev10_qsam_close_calls() == 1 && fake_dyn_unalloc_calls() == 2);

    dev10_qsam_reset();
        REQUIRE(rx_mvs_record_open(&ch, "DD:RSOUT", RS_MODE_WRITE, err, sizeof(err)) == RX_MVS_RECORD_OK);
    REQUIRE(rx_mvs_record_position(&ch, 2, err, sizeof(err)) == RX_MVS_RECORD_ERROR);
    REQUIRE(rx_mvs_record_number(&ch, &n, err, sizeof(err)) == RX_MVS_RECORD_OK && n == 1);
    REQUIRE(rx_mvs_record_close(&ch, err, sizeof(err)) == RX_MVS_RECORD_OK);
    puts("PASS MVS record positioning, metadata, unknown count, and pending cleanup");
    return 0;
}
