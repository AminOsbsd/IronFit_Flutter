package com.ironfit.repository;

import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** Pagination par décalage (?offset= & ?limit=) : l'API n'expose pas de numéros de page. */
public final class OffsetLimit implements Pageable {
    public static final int MAX = 500;
    private final long offset;
    private final int limit;

    private OffsetLimit(long offset, int limit) {
        this.offset = Math.max(0, offset);
        this.limit = Math.min(Math.max(limit, 1), MAX);
    }

    public static OffsetLimit of(Integer offset, Integer limit, int defaultLimit) {
        return new OffsetLimit(offset == null ? 0 : offset, limit == null ? defaultLimit : limit);
    }

    public static OffsetLimit first(int n) { return new OffsetLimit(0, n); }

    @Override public int getPageNumber() { return (int) (offset / limit); }
    @Override public int getPageSize() { return limit; }
    @Override public long getOffset() { return offset; }
    @Override public Sort getSort() { return Sort.unsorted(); }
    @Override public Pageable next() { return new OffsetLimit(offset + limit, limit); }
    @Override public Pageable previousOrFirst() { return new OffsetLimit(Math.max(0, offset - limit), limit); }
    @Override public Pageable first() { return new OffsetLimit(0, limit); }
    @Override public Pageable withPage(int pageNumber) { return new OffsetLimit((long) pageNumber * limit, limit); }
    @Override public boolean hasPrevious() { return offset > 0; }
}
