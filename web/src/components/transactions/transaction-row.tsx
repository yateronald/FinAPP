'use client';

import { MoreVertical, Pencil, Repeat, Trash2 } from 'lucide-react';
import { useTranslations } from 'next-intl';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Badge } from '@/components/ui/badge';
import { categoryIcon } from '@/lib/category-icons';
import { cn, formatCurrency, formatDate } from '@/lib/utils';
import type { Transaction } from '@/lib/types';

export function TransactionRow({
  tx,
  kind,
  currency,
  onEdit,
  onDelete,
}: {
  tx: Transaction;
  kind: 'INCOME' | 'EXPENSE';
  currency: string;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const tc = useTranslations('common');
  const income = kind === 'INCOME';
  const Icon = categoryIcon(tx.category.icon);
  const color = tx.category.color || (income ? '#22c55e' : '#ef4444');

  return (
    <div className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-muted/40">
      <span
        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg"
        style={{ backgroundColor: `${color}1F`, color }}
      >
        <Icon className="h-5 w-5" />
      </span>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <p className="truncate font-medium text-foreground">{tx.title}</p>
          {tx.isRecurring && <Repeat className="h-3.5 w-3.5 text-muted-foreground" />}
        </div>
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
          <span>{tx.category.name}</span>
          <span>·</span>
          <span>{formatDate(tx.date)}</span>
          {tx.paymentMethod && (
            <>
              <span>·</span>
              <span>{tx.paymentMethod}</span>
            </>
          )}
          {tx.tags?.map((tag) => (
            <Badge key={tag} variant="muted" className="px-1.5 py-0 text-[10px]">
              {tag}
            </Badge>
          ))}
        </div>
      </div>

      <span
        className={cn(
          'shrink-0 text-sm font-semibold tabular-nums',
          income ? 'text-success' : 'text-foreground',
        )}
      >
        {income ? '+' : '-'}
        {formatCurrency(tx.amount, currency)}
      </span>

      <DropdownMenu>
        <DropdownMenuTrigger className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground focus:outline-none">
          <MoreVertical className="h-4 w-4" />
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={onEdit}>
            <Pencil /> {tc('edit')}
          </DropdownMenuItem>
          <DropdownMenuItem destructive onClick={onDelete}>
            <Trash2 /> {tc('delete')}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
