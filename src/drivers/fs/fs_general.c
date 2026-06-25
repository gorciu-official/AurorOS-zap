#include <types.h>
#include <fs/fs-emulated.h>
#include <fs/filesystem.h>

void fs_remove_child(fs_node* parent, fs_node* child) {
    if (!parent || !child || parent->type != EMULATED_FS_DIR) return;

    int found = 0;
    for (uint32_t i = 0; i < parent->child_count; i++) {
        if (parent->children[i] == child) {
            found = 1;
        }
        if (found && i < parent->child_count - 1) {
            parent->children[i] = parent->children[i + 1];
        }
    }
    if (found) parent->child_count--;
}

void fs_delete(fs_node* node) {
    if (!node) return;

    if (node->type == EMULATED_FS_DIR) {
        while (node->child_count > 0) {
            fs_delete(node->children[0]);
        }
    }

    if (node->parent) {
        fs_remove_child(node->parent, node);
    }

    emulated_fs_delete(node);
}
