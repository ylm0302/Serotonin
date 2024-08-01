#include "fishhook.h"
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <Foundation/Foundation.h>
#include <bsm/audit.h>
// #include <xpc/xpc.h>
#include <stdio.h>
#include <spawn.h>
#include <limits.h>
#include <dirent.h>
#include <stdbool.h>
#include <errno.h>
// #include <roothide.h>
#include "../../jbroot.h"
#include <signal.h>

int posix_spawnattr_set_launch_type_np(posix_spawnattr_t *attr, uint8_t launch_type);

int (*orig_csops)(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
int (*orig_csops_audittoken)(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize, audit_token_t * token);


int (*orig_posix_spawnp)(pid_t *restrict pid, const char *restrict path, const posix_spawn_file_actions_t *restrict file_actions, const posix_spawnattr_t *restrict attrp, char *const argv[restrict], char *const envp[restrict]);


int hooked_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int result = orig_csops(pid, ops, useraddr, usersize);
    if (result != 0) return result;
    if (ops == 0) { // CS_OPS_STATUS
       *((uint32_t *)useraddr) |= 0x4000001; // CS_PLATFORM_BINARY
    }
    return result;
}

int hooked_csops_audittoken(pid_t pid, unsigned int ops, void * useraddr, size_t usersize, audit_token_t * token) {
    int result = orig_csops_audittoken(pid, ops, useraddr, usersize, token);
    if (result != 0) return result;
    if (ops == 0) { // CS_OPS_STATUS
       *((uint32_t *)useraddr) |= 0x4000001; // CS_PLATFORM_BINARY
    }
    return result;
}
#define INSTALLD_PATH       "/usr/libexec/installd"
#define NFCD_PATH           "/usr/libexec/nfcd"
#define MEDIASERVERD_PATH   "/usr/sbin/mediaserverd"

int hooked_posix_spawnp(pid_t *restrict pid, const char *restrict path, const posix_spawn_file_actions_t *restrict file_actions, posix_spawnattr_t *attrp, char *argv[restrict], char * envp[restrict]) {
    if (strncmp(path, "/usr/sbin/cfprefsd", 18) == 0) {
        path = jbroot("/usr/sbin/cfprefsd");
        argv[0] = (char *)path;
        posix_spawnattr_set_launch_type_np((posix_spawnattr_t *)attrp, 0);
    // } else if (!strncmp(path, MEDIASERVERD_PATH, strlen(MEDIASERVERD_PATH))) {
    //    path = jbroot(MEDIASERVERD_PATH);
    //    argv[0] = (char *)path;
    //    posix_spawnattr_set_launch_type_np((posix_spawnattr_t *)attrp, 0);
    } else if (!strncmp(path, INSTALLD_PATH, strlen(INSTALLD_PATH))) {
        path = jbroot(INSTALLD_PATH);
        argv[0] = (char *)path;
        posix_spawnattr_set_launch_type_np((posix_spawnattr_t *)attrp, 0);
    } else if (!strncmp(path, NFCD_PATH, strlen(NFCD_PATH))) {
       path = jbroot(NFCD_PATH);
       argv[0] = (char *)path;
       posix_spawnattr_set_launch_type_np((posix_spawnattr_t *)attrp, 0);
    }
    return orig_posix_spawnp(pid, path, file_actions, attrp, argv, envp);
}

__attribute__((constructor)) static void init(int argc, char **argv) {
    struct rebinding rebindings[] = (struct rebinding[]){
        {"csops", hooked_csops, (void *)&orig_csops},
        {"csops_audittoken", hooked_csops_audittoken, (void *)&orig_csops_audittoken},
        {"posix_spawnp", hooked_posix_spawnp, (void *)&orig_posix_spawnp},
    };
    rebind_symbols(rebindings, sizeof(rebindings)/sizeof(struct rebinding));
}
