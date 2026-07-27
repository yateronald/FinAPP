'use client';

import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { ChartRenderer } from './chart-renderer';

export function MarkdownMessage({ content }: { content: string }) {
  return (
    <div className="prose prose-sm dark:prose-invert max-w-none break-words prose-p:my-1.5 prose-headings:mt-3 prose-headings:mb-1.5 prose-ul:my-1.5 prose-ol:my-1.5 prose-li:my-0.5 prose-pre:my-2 prose-table:my-2">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          code(props) {
            const { className, children, ...rest } = props as any;
            const match = /language-(\w+)/.exec(className || '');
            const lang = match?.[1];
            const text = String(children ?? '').replace(/\n$/, '');
            if (lang === 'chart') {
              return <ChartRenderer raw={text} />;
            }
            const isInline = !className;
            if (isInline) {
              return (
                <code className="rounded bg-muted px-1 py-0.5 text-[0.85em]" {...rest}>
                  {children}
                </code>
              );
            }
            return (
              <code className={className} {...rest}>
                {children}
              </code>
            );
          },
          table(props) {
            return (
              <div className="my-2 overflow-x-auto rounded-lg border border-border">
                <table className="w-full border-collapse text-sm">{props.children}</table>
              </div>
            );
          },
          th(props) {
            return (
              <th className="border-b border-border bg-muted/50 px-3 py-2 text-left font-semibold">
                {props.children}
              </th>
            );
          },
          td(props) {
            return <td className="border-b border-border/60 px-3 py-2">{props.children}</td>;
          },
          a(props) {
            return (
              <a className="text-primary underline" target="_blank" rel="noreferrer">
                {props.children}
              </a>
            );
          },
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  );
}
