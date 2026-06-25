#include <types.h>
#include <memory.h>
#include <msg.h>
#include <string.h>
#include <fs/fs-emulated.h>
#include <fs/permissions/umask.h>

emulated_fs_node* emulated_fs_root;

emulated_fs_node* emulated_fs_resolve(const char* path, emulated_fs_node* current_dir) {
    emulated_fs_node* current;

    if (path[0] == '/') {
        current = emulated_fs_root;
        path++; 
    } else {
        current = current_dir;
    }

    char token[32];
    uint32_t pos = 0;

    for (uint32_t i = 0; ; i++) {
        char c = path[i];

        if (c == '/' || c == '\0') {
            token[pos] = '\0';

            if (pos > 0) {
                if (strcmp(token, ".") == 0) {
                }
                else if (strcmp(token, "..") == 0) {
                    if (current->parent != NULL)
                        current = current->parent;
                }
                else {
                    current = emulated_fs_find_in(current, token);
                    if (!current) return NULL;
                }
            }

            pos = 0;
            if (c == '\0') break;
            continue;
        }

        token[pos++] = c;
    }

    return current;
}



int emulated_fs_read(emulated_fs_node* file, uint8_t* out, uint32_t max) {
    if (file->type != EMULATED_FS_FILE) 
        return -1;

    if (file->data == NULL || file->size == 0) {
        if (max > 0) out[0] = 0;  
        return 0;
    }

    uint32_t to_copy = (file->size < max ? file->size : max - 1);

    memcpy(out, file->data, to_copy);

    out[to_copy] = 0;

    return to_copy;
}
