import { type Component, createSignal, For } from "solid-js";

type DropListProps = { class?: string, name: string, items: string[] };

const DropList: Component<DropListProps> = (props: DropListProps) => {
  const [selected, setSelected] = createSignal(0)

  return (
    <div class={`${props.class} flex flex-col`}>
      <label class="text-sm" for={props.name}>{props.name}</label>
      <select
        class="rounded-lg px-2 focus:outline-none focus:ring border-blue-500"
        name={props.name}
        title={props.name}
        value={props.items[selected()]}
        onInput={(e) =>
          setSelected((e.target as HTMLSelectElement).selectedIndex)
        }
      >
        <For each={props.items}>{(item) => <option value={item}>{item}</option>}</For>
      </select>
    </div>
  );
};

export default DropList;
