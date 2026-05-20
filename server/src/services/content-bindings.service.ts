import { Prisma } from '@prisma/client';

const uniqueIds = (ids: string[]): string[] => Array.from(new Set(ids.map((id) => id.trim()).filter(Boolean)));

export const syncPostBindings = async (
  tx: Prisma.TransactionClient,
  postId: string,
  bindings: {
    djIds?: string[];
    brandIds?: string[];
    eventIds?: string[];
  }
): Promise<void> => {
  if (bindings.djIds) {
    await tx.postDJBinding.deleteMany({ where: { postId } });
    await tx.postDJBinding.createMany({
      data: uniqueIds(bindings.djIds).map((djId, index) => ({
        postId,
        djId,
        bindingType: 'related',
        sortOrder: index + 1,
      })),
      skipDuplicates: true,
    });
  }
  if (bindings.brandIds) {
    await tx.postFestivalBrandBinding.deleteMany({ where: { postId } });
    await tx.postFestivalBrandBinding.createMany({
      data: uniqueIds(bindings.brandIds).map((festivalBrandId, index) => ({
        postId,
        festivalBrandId,
        bindingType: 'related',
        sortOrder: index + 1,
      })),
      skipDuplicates: true,
    });
  }
  if (bindings.eventIds) {
    await tx.postEventBinding.deleteMany({ where: { postId } });
    await tx.postEventBinding.createMany({
      data: uniqueIds(bindings.eventIds).map((eventId, index) => ({
        postId,
        eventId,
        bindingType: 'related',
        sortOrder: index + 1,
      })),
      skipDuplicates: true,
    });
  }
};

export const syncNewsBindings = async (
  tx: Prisma.TransactionClient,
  articleId: string,
  bindings: {
    djIds?: string[];
    brandIds?: string[];
    eventIds?: string[];
  }
): Promise<void> => {
  if (bindings.djIds) {
    await tx.newsDJBinding.deleteMany({ where: { articleId } });
    await tx.newsDJBinding.createMany({
      data: uniqueIds(bindings.djIds).map((djId, index) => ({
        articleId,
        djId,
        bindingType: 'related',
        sortOrder: index + 1,
      })),
      skipDuplicates: true,
    });
  }
  if (bindings.brandIds) {
    await tx.newsFestivalBrandBinding.deleteMany({ where: { articleId } });
    await tx.newsFestivalBrandBinding.createMany({
      data: uniqueIds(bindings.brandIds).map((festivalBrandId, index) => ({
        articleId,
        festivalBrandId,
        bindingType: 'related',
        sortOrder: index + 1,
      })),
      skipDuplicates: true,
    });
  }
  if (bindings.eventIds) {
    await tx.newsEventBinding.deleteMany({ where: { articleId } });
    await tx.newsEventBinding.createMany({
      data: uniqueIds(bindings.eventIds).map((eventId, index) => ({
        articleId,
        eventId,
        bindingType: 'related',
        sortOrder: index + 1,
      })),
      skipDuplicates: true,
    });
  }
};

export const includePostBindings = {
  djBindings: { orderBy: { sortOrder: 'asc' as const }, select: { djId: true } },
  festivalBrandBindings: { orderBy: { sortOrder: 'asc' as const }, select: { festivalBrandId: true } },
  eventBindings: { orderBy: { sortOrder: 'asc' as const }, select: { eventId: true } },
} as const;

export const includeNewsBindings = {
  djBindings: { orderBy: { sortOrder: 'asc' as const }, select: { djId: true } },
  festivalBrandBindings: { orderBy: { sortOrder: 'asc' as const }, select: { festivalBrandId: true } },
  eventBindings: { orderBy: { sortOrder: 'asc' as const }, select: { eventId: true } },
} as const;

export const derivePostBindingIds = (post: {
  djBindings?: Array<{ djId: string }> | null;
  festivalBrandBindings?: Array<{ festivalBrandId: string }> | null;
  eventBindings?: Array<{ eventId: string }> | null;
}) => ({
  djIds: post.djBindings?.map((binding) => binding.djId) ?? [],
  brandIds: post.festivalBrandBindings?.map((binding) => binding.festivalBrandId) ?? [],
  eventIds: post.eventBindings?.map((binding) => binding.eventId) ?? [],
});

export const deriveNewsBindingIds = (article: {
  djBindings?: Array<{ djId: string }> | null;
  festivalBrandBindings?: Array<{ festivalBrandId: string }> | null;
  eventBindings?: Array<{ eventId: string }> | null;
}) => ({
  djIds: article.djBindings?.map((binding) => binding.djId) ?? [],
  brandIds: article.festivalBrandBindings?.map((binding) => binding.festivalBrandId) ?? [],
  eventIds: article.eventBindings?.map((binding) => binding.eventId) ?? [],
});
