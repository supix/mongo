/*-
 * See the file LICENSE for redistribution information.
 *
 * Copyright (c) 2008-2011 WiredTiger, Inc.
 *	All rights reserved.
 */

/*
 * __wt_cache_page_workq --
 *	Create pages into the cache.
 */
static inline void
__wt_cache_page_workq(WT_SESSION_IMPL *session)
{
	WT_CACHE *cache;

	cache = S2C(session)->cache;

	++cache->pages_workq;
}

/*
 * __wt_cache_page_workq_incr --
 *	Increment a page's memory footprint in the cache.
 */
static inline void
__wt_cache_page_workq_incr(
    WT_SESSION_IMPL *session, WT_PAGE *page, uint32_t size)
{
	WT_CACHE *cache;

	cache = S2C(session)->cache;

	cache->bytes_workq += size;
	page->memory_footprint += size;
}

/*
 * __wt_cache_page_read --
 *	Read pages into the cache.
 */
static inline void
__wt_cache_page_read(WT_SESSION_IMPL *session, WT_PAGE *page, uint32_t size)
{
	WT_CACHE *cache;

	cache = S2C(session)->cache;

	WT_ASSERT(session, size != 0);
	WT_ASSERT(session, page->memory_footprint == 0);

	++cache->pages_read;
	cache->bytes_read += size;

	page->memory_footprint = size;
}

/*
 * __wt_cache_page_evict --
 *	Evict pages from the cache.
 */
static inline void
__wt_cache_page_evict(WT_SESSION_IMPL *session, WT_PAGE *page)
{
	WT_CACHE *cache;

	cache = S2C(session)->cache;

	WT_ASSERT(session, page->memory_footprint != 0);

	++cache->pages_evict;
	cache->bytes_evict += page->memory_footprint;

	page->memory_footprint = 0;
}

static inline uint64_t
__wt_cache_read_gen(WT_SESSION_IMPL *session)
{
	return (++S2C(session)->cache->read_gen);
}

/*
 * __wt_cache_pages_inuse --
 *	Return the number of pages in use.
 */
static inline uint64_t
__wt_cache_pages_inuse(WT_CACHE *cache)
{
	uint64_t pages_in, pages_out;

	/*
	 * Reading 64-bit fields, potentially on 32-bit machines, and other
	 * threads of control may be modifying them.  Check them for sanity
	 * (although "interesting" corruption is vanishingly unlikely, these
	 * values just increment over time).
	 */
	pages_in = cache->pages_read + cache->pages_workq;
	pages_out = cache->pages_evict;
	return (pages_in > pages_out ? pages_in - pages_out : 0);
}

/*
 * __wt_cache_bytes_inuse --
 *	Return the number of bytes in use.
 */
static inline uint64_t
__wt_cache_bytes_inuse(WT_CACHE *cache)
{
	uint64_t bytes_in, bytes_out;

	/*
	 * Reading 64-bit fields, potentially on 32-bit machines, and other
	 * threads of control may be modifying them.  Check them for sanity
	 * (although "interesting" corruption is vanishingly unlikely, these
	 * values just increment over time).
	 */
	bytes_in = cache->bytes_read + cache->bytes_workq;
	bytes_out = cache->bytes_evict;
	return (bytes_in > bytes_out ? bytes_in - bytes_out : 0);
}

/*
 * __wt_page_write_gen_check --
 *	Confirm the page's write generation number is correct.
 */
static inline int
__wt_page_write_gen_check(WT_PAGE *page, uint32_t write_gen)
{
	return (page->write_gen == write_gen ? 0 : WT_RESTART);
}

/*
 * __wt_off_page --
 *	Return if a pointer references off-page data.
 */
static inline int
__wt_off_page(WT_PAGE *page, const void *p)
{
	/*
	 * There may be no underlying page, in which case the reference is
	 * off-page by definition.
	 *
	 * We use the page's disk size, not the page parent's reference disk
	 * size for a reason: the page may already be disconnected from the
	 * parent reference (when being discarded), or not yet be connected
	 * to the parent reference (when being created).
	 */
	return (page->dsk == NULL ||
	    p < (void *)page->dsk ||
	    p >= (void *)((uint8_t *)page->dsk + page->dsk->size));
}

/*
 * __wt_page_reconcile --
 *	Standard version of page reconciliation.
 */
static inline int
__wt_page_reconcile(WT_SESSION_IMPL *session, WT_PAGE *page, uint32_t flags)
{
	/*
	 * There's an internal version of page reconciliation that salvage uses,
	 * everybody else just calls with a value of NULL as the 3rd argument.
	 */
	return (__wt_page_reconcile_int(session, page, NULL, flags));
}

/*
 * __wt_page_out --
 *	Release a reference to a page, unless it's the root page, which remains
 * pinned for the life of the table handle.
 */
static inline void
__wt_page_out(WT_SESSION_IMPL *session, WT_PAGE *page)
{
	if (page != NULL && !WT_PAGE_IS_ROOT(page))
		__wt_hazard_clear(session, page);
}
