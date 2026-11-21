#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <stdio.h>
#include <dlfcn.h>
#include "svdpi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* VCS error reporting routine */
extern void vcsMsgReport1(const char *, const char *, int, void *, void*, const char *);

#ifndef _VC_TYPES_
#define _VC_TYPES_
/* common definitions shared with DirectC.h */

typedef unsigned int U;
typedef unsigned char UB;
typedef unsigned char scalar;
typedef struct { U c; U d;} vec32;

#define scalar_0 0
#define scalar_1 1
#define scalar_z 2
#define scalar_x 3

extern long long int ConvUP2LLI(U* a);
extern void ConvLLI2UP(long long int a1, U* a2);
extern long long int GetLLIresult();
extern void StoreLLIresult(const unsigned int* data);
typedef struct VeriC_Descriptor *vc_handle;

#ifndef SV_3_COMPATIBILITY
#define SV_STRING const char*
#else
#define SV_STRING char*
#endif

#endif /* _VC_TYPES_ */

#ifndef __VCS_IMPORT_DPI_STUB_reset_fifo
#define __VCS_IMPORT_DPI_STUB_reset_fifo
__attribute__((weak)) void reset_fifo()
{
    static int _vcs_dpi_stub_initialized_ = 0;
    static void (*_vcs_dpi_fp_)() = NULL;
    if (!_vcs_dpi_stub_initialized_) {
        _vcs_dpi_fp_ = (void (*)()) dlsym(RTLD_NEXT, "reset_fifo");
        _vcs_dpi_stub_initialized_ = 1;
    }
    if (_vcs_dpi_fp_) {
        _vcs_dpi_fp_();
    } else {
        const char *fileName;
        int lineNumber;
        svGetCallerInfo(&fileName, &lineNumber);
        vcsMsgReport1("DPI-DIFNF", fileName, lineNumber, 0, 0, "reset_fifo");
    }
}
#endif /* __VCS_IMPORT_DPI_STUB_reset_fifo */

#ifndef __VCS_IMPORT_DPI_STUB_push_fifo
#define __VCS_IMPORT_DPI_STUB_push_fifo
__attribute__((weak)) int push_fifo(/* INPUT */int A_1)
{
    static int _vcs_dpi_stub_initialized_ = 0;
    static int (*_vcs_dpi_fp_)(/* INPUT */int A_1) = NULL;
    if (!_vcs_dpi_stub_initialized_) {
        _vcs_dpi_fp_ = (int (*)(int A_1)) dlsym(RTLD_NEXT, "push_fifo");
        _vcs_dpi_stub_initialized_ = 1;
    }
    if (_vcs_dpi_fp_) {
        return _vcs_dpi_fp_(A_1);
    } else {
        const char *fileName;
        int lineNumber;
        svGetCallerInfo(&fileName, &lineNumber);
        vcsMsgReport1("DPI-DIFNF", fileName, lineNumber, 0, 0, "push_fifo");
        return 0;
    }
}
#endif /* __VCS_IMPORT_DPI_STUB_push_fifo */

#ifndef __VCS_IMPORT_DPI_STUB_pop_fifo
#define __VCS_IMPORT_DPI_STUB_pop_fifo
__attribute__((weak)) int pop_fifo(/* OUTPUT */int *A_1)
{
    static int _vcs_dpi_stub_initialized_ = 0;
    static int (*_vcs_dpi_fp_)(/* OUTPUT */int *A_1) = NULL;
    if (!_vcs_dpi_stub_initialized_) {
        _vcs_dpi_fp_ = (int (*)(int* A_1)) dlsym(RTLD_NEXT, "pop_fifo");
        _vcs_dpi_stub_initialized_ = 1;
    }
    if (_vcs_dpi_fp_) {
        return _vcs_dpi_fp_(A_1);
    } else {
        const char *fileName;
        int lineNumber;
        svGetCallerInfo(&fileName, &lineNumber);
        vcsMsgReport1("DPI-DIFNF", fileName, lineNumber, 0, 0, "pop_fifo");
        return 0;
    }
}
#endif /* __VCS_IMPORT_DPI_STUB_pop_fifo */

#ifndef __VCS_IMPORT_DPI_STUB_fifo_count
#define __VCS_IMPORT_DPI_STUB_fifo_count
__attribute__((weak)) int fifo_count()
{
    static int _vcs_dpi_stub_initialized_ = 0;
    static int (*_vcs_dpi_fp_)() = NULL;
    if (!_vcs_dpi_stub_initialized_) {
        _vcs_dpi_fp_ = (int (*)()) dlsym(RTLD_NEXT, "fifo_count");
        _vcs_dpi_stub_initialized_ = 1;
    }
    if (_vcs_dpi_fp_) {
        return _vcs_dpi_fp_();
    } else {
        const char *fileName;
        int lineNumber;
        svGetCallerInfo(&fileName, &lineNumber);
        vcsMsgReport1("DPI-DIFNF", fileName, lineNumber, 0, 0, "fifo_count");
        return 0;
    }
}
#endif /* __VCS_IMPORT_DPI_STUB_fifo_count */

#ifndef __VCS_IMPORT_DPI_STUB_is_fifo_empty
#define __VCS_IMPORT_DPI_STUB_is_fifo_empty
__attribute__((weak)) int is_fifo_empty()
{
    static int _vcs_dpi_stub_initialized_ = 0;
    static int (*_vcs_dpi_fp_)() = NULL;
    if (!_vcs_dpi_stub_initialized_) {
        _vcs_dpi_fp_ = (int (*)()) dlsym(RTLD_NEXT, "is_fifo_empty");
        _vcs_dpi_stub_initialized_ = 1;
    }
    if (_vcs_dpi_fp_) {
        return _vcs_dpi_fp_();
    } else {
        const char *fileName;
        int lineNumber;
        svGetCallerInfo(&fileName, &lineNumber);
        vcsMsgReport1("DPI-DIFNF", fileName, lineNumber, 0, 0, "is_fifo_empty");
        return 0;
    }
}
#endif /* __VCS_IMPORT_DPI_STUB_is_fifo_empty */

#ifndef __VCS_IMPORT_DPI_STUB_is_fifo_full
#define __VCS_IMPORT_DPI_STUB_is_fifo_full
__attribute__((weak)) int is_fifo_full()
{
    static int _vcs_dpi_stub_initialized_ = 0;
    static int (*_vcs_dpi_fp_)() = NULL;
    if (!_vcs_dpi_stub_initialized_) {
        _vcs_dpi_fp_ = (int (*)()) dlsym(RTLD_NEXT, "is_fifo_full");
        _vcs_dpi_stub_initialized_ = 1;
    }
    if (_vcs_dpi_fp_) {
        return _vcs_dpi_fp_();
    } else {
        const char *fileName;
        int lineNumber;
        svGetCallerInfo(&fileName, &lineNumber);
        vcsMsgReport1("DPI-DIFNF", fileName, lineNumber, 0, 0, "is_fifo_full");
        return 0;
    }
}
#endif /* __VCS_IMPORT_DPI_STUB_is_fifo_full */


#ifdef __cplusplus
}
#endif

