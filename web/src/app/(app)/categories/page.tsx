'use client';

import { useState } from 'react';
import {
  Archive,
  ArchiveRestore,
  LayoutGrid,
  MoreVertical,
  Pencil,
  Plus,
  Trash2,
} from 'lucide-react';
import { useTranslations } from 'next-intl';
import { toast } from 'sonner';
import { PageHeader } from '@/components/page-header';
import { EmptyState } from '@/components/empty-state';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { CategoryFormDialog } from '@/components/categories/category-form-dialog';
import { useCategories, useCategoryMutations } from '@/hooks/use-categories';
import { categoryIcon } from '@/lib/category-icons';
import { cn } from '@/lib/utils';
import type { Category } from '@/lib/types';

function CategoryGrid({ type }: { type: 'INCOME' | 'EXPENSE' }) {
  const t = useTranslations('categories');
  const tc = useTranslations('common');
  const { data, isLoading } = useCategories(type, true);
  const { create, update, archive, remove } = useCategoryMutations();

  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [deleting, setDeleting] = useState<Category | null>(null);

  const submit = (values: { name: string; icon: string; color: string }) => {
    if (editing) {
      update.mutate(
        { id: editing.id, ...values },
        {
          onSuccess: () => {
            toast.success(t('updated'));
            setFormOpen(false);
          },
          onError: (e: any) => toast.error(e?.message),
        },
      );
    } else {
      create.mutate(
        { ...values, type },
        {
          onSuccess: () => {
            toast.success(t('created'));
            setFormOpen(false);
          },
          onError: (e: any) => toast.error(e?.message),
        },
      );
    }
  };

  const items = data ?? [];

  if (isLoading) {
    return (
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-20 rounded-xl" />
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button
          size="sm"
          onClick={() => {
            setEditing(null);
            setFormOpen(true);
          }}
        >
          <Plus className="h-4 w-4" /> {t('add')}
        </Button>
      </div>

      {items.length === 0 ? (
        <Card>
          <CardContent className="p-0">
            <EmptyState icon={LayoutGrid} title={t('empty')} />
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {items.map((cat) => {
            const Icon = categoryIcon(cat.icon);
            const color = cat.color || '#94a3b8';
            return (
              <Card
                key={cat.id}
                className={cn('transition-colors', cat.isArchived && 'opacity-60')}
              >
                <CardContent className="flex items-center gap-3 p-4">
                  <span
                    className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl"
                    style={{ backgroundColor: `${color}26`, color }}
                  >
                    <Icon className="h-5 w-5" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium text-foreground">{cat.name}</p>
                    <div className="mt-0.5 flex flex-wrap gap-1">
                      {cat.isDefault && (
                        <Badge variant="muted" className="px-1.5 py-0 text-[10px]">
                          {t('default')}
                        </Badge>
                      )}
                      {cat.isArchived && (
                        <Badge variant="warning" className="px-1.5 py-0 text-[10px]">
                          {t('archived')}
                        </Badge>
                      )}
                    </div>
                  </div>
                  <DropdownMenu>
                    <DropdownMenuTrigger className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground focus:outline-none">
                      <MoreVertical className="h-4 w-4" />
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem
                        onClick={() => {
                          setEditing(cat);
                          setFormOpen(true);
                        }}
                      >
                        <Pencil /> {tc('edit')}
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        onClick={() =>
                          archive.mutate(
                            { id: cat.id, archived: !cat.isArchived },
                            {
                              onSuccess: () =>
                                toast.success(
                                  cat.isArchived ? t('unarchivedToast') : t('archivedToast'),
                                ),
                            },
                          )
                        }
                      >
                        {cat.isArchived ? <ArchiveRestore /> : <Archive />}
                        {cat.isArchived ? t('unarchive') : t('archive')}
                      </DropdownMenuItem>
                      {!cat.isDefault && (
                        <>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem destructive onClick={() => setDeleting(cat)}>
                            <Trash2 /> {tc('delete')}
                          </DropdownMenuItem>
                        </>
                      )}
                    </DropdownMenuContent>
                  </DropdownMenu>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      <CategoryFormDialog
        open={formOpen}
        onOpenChange={setFormOpen}
        type={type}
        editing={editing}
        onSubmit={submit}
        saving={create.isPending || update.isPending}
      />
      <ConfirmDialog
        open={!!deleting}
        onOpenChange={(o) => !o && setDeleting(null)}
        title={t('deleteConfirm')}
        description={t('deleteDesc')}
        loading={remove.isPending}
        onConfirm={() =>
          deleting &&
          remove.mutate(deleting.id, {
            onSuccess: () => {
              toast.success(t('deleted'));
              setDeleting(null);
            },
            onError: (e: any) => toast.error(e?.message),
          })
        }
      />
    </div>
  );
}

export default function CategoriesPage() {
  const t = useTranslations('categories');

  return (
    <div className="space-y-6">
      <PageHeader title={t('title')} description={t('subtitle')} />
      <Tabs defaultValue="EXPENSE">
        <TabsList>
          <TabsTrigger value="EXPENSE">{t('expenseTab')}</TabsTrigger>
          <TabsTrigger value="INCOME">{t('incomeTab')}</TabsTrigger>
        </TabsList>
        <TabsContent value="EXPENSE">
          <CategoryGrid type="EXPENSE" />
        </TabsContent>
        <TabsContent value="INCOME">
          <CategoryGrid type="INCOME" />
        </TabsContent>
      </Tabs>
    </div>
  );
}
