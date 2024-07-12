import { type Component, createSignal, For, type Setter, createEffect } from "solid-js";

type DropListProps = {
  class?: string,
  name: string,
  items: string[],
  setValue: Setter<string>,
  value?: string
};

const DropList: Component<DropListProps> = (props: DropListProps) => {
  console.log(props);

  return (
    <div class={`${props.class} flex flex-col`}>
      <label class="text-sm" for={props.name}>{props.name}</label>
      <select
        class="rounded-lg px-2 focus:outline-none focus:ring border-blue-500"
        name={props.name}
        title={props.name}
        value={props.value || props.items.length > 0 ? props.items[0] : ""}
        onInput={(e) =>
          props.setValue((e.currentTarget as HTMLSelectElement).value)
        }
      >
        <For each={props.items}>{(item) => <option value={item}>{item}</option>}</For>
      </select>
    </div>
  );
};

export default DropList;
