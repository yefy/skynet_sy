#ifndef SKPQUEUE_H
#define SKPQUEUE_H

#define QUEUE_HEAD(name, type) \
struct name { \
    type *first; \
    type *last; \
}

#define QUEUE_NODE(type) \
struct { \
    type *next; \
    type *prev; \
}

#define QUEUE_INIT(head) \
    do { \
        (head)->first = (head)->last = NULL; \
    } while(0)

#define QUEUE_MOVE(head_dest, head_src) \
    do { \
        (head_dest)->first = (head_src)->first; \
        (head_dest)->last = (head_src)->last; \
        QUEUE_INIT(head_src); \
    }while(0)

#define QUEUE_NODE_INIT(node, chain) \
    do { \
        (node)->chain.prev = NULL; \
        (node)->chain.next = NULL; \
    } while(0)

#define QUEUE_EMPTY(head) ((head)->first == NULL)

#define QUEUE_FIRST(head, new_node) \
    do { \
        if(QUEUE_EMPTY((head))) { \
            (new_node) = NULL; \
            break; \
        } \
        (new_node) = (head)->first; \
    }while(0)

#define QUEUE_LAST(head, new_node) \
    do { \
        if(QUEUE_EMPTY((head))) { \
            (new_node) = NULL; \
            break; \
        } \
        (new_node) = (head)->last; \
    }while(0)

#define QUEUE_INSERT_FIRST(head, node, chain) \
    do { \
        if (QUEUE_EMPTY(head)) { \
            (head)->first = (head)->last = (node); \
            (node)->chain.prev = NULL; \
            (node)->chain.next = NULL; \
        } else { \
            (node)->chain.prev = NULL; \
            (node)->chain.next = (head)->first; \
            (head)->first->chain.prev = (node); \
            (head)->first = (node); \
        } \
    } while(0)

#define QUEUE_INSETT_LAST(head, node, chain) \
    do { \
        if (QUEUE_EMPTY(head)) { \
            (head)->first = (head)->last = (node); \
            (node)->chain.prev = NULL; \
            (node)->chain.next = NULL; \
        } else { \
            (head)->last->chain.next = (node); \
            (node)->chain.prev = (head)->last; \
            (node)->chain.next = NULL; \
            (head)->last = (node); \
        } \
    } while(0)

#define QUEUE_INSETT_NODE(head, node, node2, chain) \
    do { \
        if(QUEUE_EMPTY(head)) { \
            break; \
        } \
        else if ((node) == (head)->last) { \
            QUEUE_INSETT_LAST(head, node2, chain); \
        } else { \
            (node)->chain.next->chain.prev = (node2); \
            (node2)->chain.next = (node)->chain.next; \
            (node2)->chain.prev = (node); \
            (node)->chain.next = (node2); \
        } \
    } while(0)


#define QUEUE_REMOVE(head, node, chain) \
    do { \
        if(QUEUE_EMPTY((head))) { \
            break; \
        } else if((head)->first == (head)->last) { \
            QUEUE_INIT((head)); \
        } else if((node)->chain.prev == NULL) { \
            (head)->first = (node)->chain.next; \
            (node)->chain.next = NULL; \
            (head)->first->chain.prev = NULL; \
        } else if((node)->chain.next == NULL) { \
            (head)->last = (node)->chain.prev; \
            (node)->chain.prev = NULL; \
            (head)->last->chain.next = NULL; \
        } else { \
            (node)->chain.prev->chain.next = (node)->chain.next; \
            (node)->chain.next->chain.prev = (node)->chain.prev; \
            (node)->chain.prev = NULL; \
            (node)->chain.next = NULL; \
        } \
    } while(0)

#define QUEUE_REMOVE_FIRST(head, chain, new_node) \
    do { \
        QUEUE_FIRST((head), (new_node)); \
        if(!(new_node)) { \
            break; \
        } \
        QUEUE_REMOVE((head), (new_node), chain); \
    }while(0)

#define QUEUE_REMOVE_LAST(head, chain, new_node) \
    do { \
        QUEUE_LAST((head), (new_node)); \
        if(!(new_node)) { \
            break; \
        } \
        QUEUE_REMOVE((head), (new_node), chain); \
    }while(0)

#endif // SKPQUEUE_H
