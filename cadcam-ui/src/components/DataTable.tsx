import { For, Show, Resource, JSX } from "solid-js";
import "./DataTable.css";

export interface TableColumn<T> {
  key: keyof T;
  header: string;
  render?: (value: any, row: T) => JSX.Element;
  className?: string;
}

interface DataTableProps<T> {
  data: Resource<T[]>;
  columns: TableColumn<T>[];
  loadingMessage?: string;
  errorMessage?: string;
  noDataMessage?: string;
}

export function DataTable<T>(props: DataTableProps<T>) {
  return (
    <div class="data-table-container">
      <Show
        when={!props.data.loading}
        fallback={<div class="table-state loading">{props.loadingMessage || "Loading..."}</div>}
      >
        <Show
          when={!props.data.error}
          fallback={<div class="table-state error">Error: {props.data.error?.message || props.errorMessage || "An error occurred"}</div>}
        >
          <Show
            when={props.data() && props.data()!.length > 0}
            fallback={<div class="table-state no-data">{props.noDataMessage || "No data found"}</div>}
          >
            <div class="table-wrapper">
              <table class="data-table">
                <thead>
                  <tr>
                    <For each={props.columns}>
                      {(column) => <th>{column.header}</th>}
                    </For>
                  </tr>
                </thead>
                <tbody>
                  <For each={props.data()}>
                    {(row) => (
                      <tr>
                        <For each={props.columns}>
                          {(column) => (
                            <td class={column.className}>
                              {column.render 
                                ? column.render(row[column.key], row)
                                : String(row[column.key])
                              }
                            </td>
                          )}
                        </For>
                      </tr>
                    )}
                  </For>
                </tbody>
              </table>
            </div>
          </Show>
        </Show>
      </Show>
    </div>
  );
}