#include <libpayload.h>
#include <cbfs.h>
#include <lzma.h>

#define ERROR printf 
#define INFO printf 
#define DEBUG printf 

#define MAX_TARGETS 10

// Return the value of a linker script symbol (see scripts/layoutrom.py)
#define SYMBOL(SYM) ({ extern char SYM; (u32)&SYM; })
#define VSYMBOL(SYM) ((void*)SYMBOL(SYM))
#define __noreturn __attribute__((noreturn))


void wait(void);
void wait(void) {
	printf("hit ESC to continue ");
	while (getchar()!=27) {printf(".");}
	printf("#\n");
}


void run_payload(struct cbfs_payload *pay);
void run_payload(struct cbfs_payload *pay) {
	struct cbfs_payload_segment *seg = &pay->segments;
	for (;;) {
		void *src = (void*)pay + ntohl(seg->offset);
		void *dest = (void*)(u32)ntohll(seg->load_addr);
		u32 src_len = ntohl(seg->len);
		u32 dest_len = ntohl(seg->mem_len);
		switch (seg->type) {
		case PAYLOAD_SEGMENT_BSS:
			DEBUG("BSS segment %d@%p\n", dest_len, dest);
//			memset(dest, 0, dest_len);
			break;
		case PAYLOAD_SEGMENT_ENTRY: {
			INFO("Calling addr %p\n", dest);
wait();
			void (*func)(void) = dest;
			func();
			return;
		}
		default:
			DEBUG("Segment %x %d@%p -> %d@%p compression %x\n"
					, seg->type, src_len, src, dest_len, dest, ntohl(seg->compression));
			void *dest_end = dest + dest_len;
//wait();
			if ((VSYMBOL(_start) <= dest && dest <= VSYMBOL(_end)) ||
				(VSYMBOL(_start) <= dest_end && dest_end <= VSYMBOL(_end)) ||
				(dest <= VSYMBOL(_start) && VSYMBOL(_start) <= dest_end)) {
				ERROR("Overlap!\n");
wait();
				return;
			}
			if (seg->compression == htonl(CBFS_COMPRESS_NONE)) {
//				DEBUG("no compression\n");
//wait();
				if (src_len > dest_len)
					src_len = dest_len;
				memcpy(dest, src, src_len);
			} else if (seg->compression == htonl(CBFS_COMPRESS_LZMA)) {
//				DEBUG("running ulzman\n");
//wait();
				int ret = ulzman(src, src_len, dest, dest_len);
				if (ret < 0)
					return;
				src_len = ret;
			} else {
				ERROR("No support for compression type %x\n"
						, seg->compression);
wait();
				return;
			}
	
			if (dest_len > src_len) {
				DEBUG("zeropad\n");
//wait();
				memset(dest + src_len, 0, dest_len - src_len);
			}
			break;
		}
		seg++;
	}
}

int reloc=0;
int main(void) {
	struct cbfs_media media;
	const struct cbfs_header *header;
        uint32_t offset, target = 1;
        struct cbfs_file *file;
	char *targets[MAX_TARGETS];
	int i;
	printf("coremenu main at %p / %p\n", &main, (void *)virt_to_phys(&main));

	if (init_default_cbfs_media(&media) != 0) {
    		ERROR("CBFS: init failed\n");
		halt();
	}

        header = get_cbfs_header();
        if (!header) {
                ERROR("CBFS: header failed\n");
		halt();
        }
	if (media.open(&media) != 0) {
    		ERROR("CBFS: open failed\n");
		halt();
	}

	offset = ntohl(header->offset);
	file = media.map(&media, offset, sizeof(struct cbfs_file));
        DEBUG("CBFS: starting at %p\n", file);

	memset(targets, 0, sizeof(targets));

        while (file) {
		int want = 0;
		// is this actualy a file?
		if (memcmp(CBFS_FILE_MAGIC, file->magic,
			sizeof(file->magic)) != 0) {
        		DEBUG("CBFS: bad magic at %p\n", file);
			file = NULL;
			break;
		}

//		DEBUG("CBFS: %p file len %x, type %x, aoffs %x, offs %x, name '%s'\n", file, 
//				ntohl(file->len), ntohl(file->type), ntohl(file->attributes_offset), ntohl(file->offset), 
//				file->filename);

		// match
		if (memcmp("img/", file->filename, 4) == 0) {
			want = 1;
		} else if (memcmp("payload/", file->filename, 8) == 0) {
			want = 1;
		} else if (memcmp("payload", file->filename, 7) == 0) {
			want = 1;
		} else if (memcmp("normal/payload", file->filename, 14) == 0) {
			want = 1;
		} else if (memcmp("fallback/payload", file->filename, 16) == 0) {
			want = 1;
		}

		if (want && (target < MAX_TARGETS)) {
			targets[target] = file->filename;
			target++;
		}

		// next file
		offset += ntohl(file->offset) + ntohl(file->len);
                if (offset % CBFS_ALIGNMENT)
                        offset += CBFS_ALIGNMENT - (offset % CBFS_ALIGNMENT);
		file = media.map(&media, offset, sizeof(struct cbfs_file));
	}


	// draw menu
REDRAW:
	printf("\n");
	for (i = 0; i < MAX_TARGETS; i++) {
		if (!targets[i]) {
			continue;
		}
		printf("  %u - %s\n", i, targets[i]);
	}

	while (1) {
		int input = getchar();
		DEBUG("UI: getchar %x\n", input);
		if (input >= '0' && input <= '9') {
			i = input - '0';
		}
		if (i >= 0 && i < MAX_TARGETS && targets[i]) {
			break;
		}
	}	
	DEBUG("UI: picked %u\n",i);

	if (targets[i]) {
		INFO("loading payload %u - %s\n", i, targets[i]);
		struct cbfs_payload *payload = cbfs_load_payload(&media, targets[i]);
		DEBUG("payload at %p\n", payload);
		if (!payload) {
			ERROR("payload load failed\n");
			goto REDRAW;
		}
		run_payload(payload);
		ERROR("payload run failed\n");
		goto REDRAW;
	}

	printf("\n### halting ###\n");
	halt();
	return 0;
}



