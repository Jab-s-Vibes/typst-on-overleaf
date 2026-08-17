/* Overleaf sandbox blocks poll(2) with EPERM. Rust std's
 * sanitize_standard_fds() aborts on that. Return EINVAL instead:
 * std falls back to fcntl(F_GETFD), which the sandbox allows. */
#define _GNU_SOURCE
#include <poll.h>
#include <errno.h>
int poll(struct pollfd *fds, nfds_t nfds, int timeout) {
    (void)fds; (void)nfds; (void)timeout;
    errno = EINVAL;
    return -1;
}
