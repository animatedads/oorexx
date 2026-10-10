#include <stdio.h>
#include <string.h>
#include "MvsRecordProvider.h"
#include "RecordSetMvsQsam.h"

void dev10_qsam_reset(void);
void dev10_qsam_close_rc(int rc);
void dev10_qsam_read_rc(int rc);
int dev10_qsam_open_calls(void);
int dev10_qsam_close_calls(void);

#define CHECK(x) do { if (!(x)) { fprintf(stderr,"FAIL line %d: %s\n",__LINE__,#x); return 1; } } while (0)
int main(void)
{
    RxMvsRecordChannel r;
    unsigned char *rec;
    rs_size_t length;
    char error[200];
    dev10_qsam_reset();
    rx_mvs_record_init(&r);
    CHECK(rx_mvs_record_open(&r, "DD:RSIN", RS_MODE_READ,error,sizeof(error)) == RX_MVS_RECORD_OK);
    CHECK(rx_mvs_record_open(&r, "DD:OTHER", RS_MODE_READ,error,sizeof(error)) == RX_MVS_RECORD_ERROR);
    CHECK(dev10_qsam_open_calls() == 1);
    /* Empty record is data, not end-of-file. A real buffer remains owned. */
    dev10_qsam_read_rc(MVSRS_QSAM_OK);
    rec = (unsigned char *)1;
    length = 9;
    CHECK(rx_mvs_record_read(&r,&rec,&length,error,sizeof(error)) == RX_MVS_RECORD_OK);
    CHECK(rec != 0 && length == 0);
    rx_mvs_record_free(rec);
    dev10_qsam_read_rc(MVSRS_QSAM_EOF);
    rec = (unsigned char *)1;
    length = 9;
    CHECK(rx_mvs_record_read(&r,&rec,&length,error,sizeof(error)) == RX_MVS_RECORD_EOF);
    CHECK(rec == 0 && length == 0);
    CHECK(rx_mvs_record_write(&r,(const unsigned char *)"X",1,error,sizeof(error)) == RX_MVS_RECORD_ERROR);
    /* Failed QSAM close must keep handle alive, block I/O and allow retry. */
    dev10_qsam_close_rc(MVSRS_QSAM_ERROR);
    CHECK(rx_mvs_record_close(&r,error,sizeof(error)) == RX_MVS_RECORD_ERROR);
    CHECK(r.backend != 0 && r.closePending);
    CHECK(rx_mvs_record_read(&r,&rec,&length,error,sizeof(error)) == RX_MVS_RECORD_ERROR);
    CHECK(rx_mvs_record_open(&r,"DD:RSIN",RS_MODE_READ,error,sizeof(error)) == RX_MVS_RECORD_ERROR);
    dev10_qsam_close_rc(MVSRS_QSAM_OK);
    CHECK(rx_mvs_record_close(&r,error,sizeof(error)) == RX_MVS_RECORD_OK);
    CHECK(r.backend == 0 && !r.closePending && dev10_qsam_close_calls() == 2);
    CHECK(rx_mvs_record_close(&r,error,sizeof(error)) == RX_MVS_RECORD_OK);
    CHECK(rx_mvs_record_open(&r,"/tmp/unix-file",RS_MODE_READ,error,sizeof(error)) == RX_MVS_RECORD_ERROR);
    CHECK(r.backend == 0);
    CHECK(rx_mvs_record_open(&r,"DD:RSOUT",RS_MODE_WRITE,error,sizeof(error)) == RX_MVS_RECORD_OK);
    CHECK(rx_mvs_record_write(&r,(const unsigned char *)"ABC",3,error,sizeof(error)) == RX_MVS_RECORD_OK);
    CHECK(rx_mvs_record_close(&r,error,sizeof(error)) == RX_MVS_RECORD_OK);
    puts("PASS MVS RecordSet host seam, EOF, DD and retryable close");
    return 0;
}
