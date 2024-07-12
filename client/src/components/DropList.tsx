import { type Component, type Accessor, type Setter } from "solid-js";
import { Select } from "@kobalte/core/select";
import { FiCheck, FiChevronDown } from "solid-icons/fi";
import "./DropList.css";

type DropListProps = {
  class?: string;
  name: string;
  items: string[];
  setValue: Setter<string>;
  value: Accessor<string>;
};

const DropList: Component<DropListProps> = (props: DropListProps) => {
  console.log(props);

  return (
    <Select
      class="m-2"
      options={props.items}
      value={props.value()}
      onChange={props.setValue}
      placeholder="select an item..."
      itemComponent={(props) => (
        <Select.Item item={props.item} class="select__item">
          <Select.ItemLabel>{props.item.rawValue}</Select.ItemLabel>
          <Select.ItemIndicator class="select__item-indicator">
            <FiCheck />
          </Select.ItemIndicator>
        </Select.Item>
      )}
    >
      <Select.Trigger class="select__trigger" aria-label={props.name}>
        <Select.Value<string> class="select__value">
          {(state) => state.selectedOption()}
        </Select.Value>
        <Select.Icon class="select__icon">
          <FiChevronDown />
        </Select.Icon>
      </Select.Trigger>
      <Select.Portal>
        <Select.Content class="select__content">
          <Select.Listbox class="select__listbox" />
        </Select.Content>
      </Select.Portal>
    </Select>
  );
};

export default DropList;
