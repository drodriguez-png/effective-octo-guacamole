import { createSignal, JSX, onCleanup, ParentComponent } from 'solid-js';

interface DropdownProps {
  trigger: JSX.Element;
  class?: string;
  contentClass?: string;
  alignRight?: boolean;
}

// stolen from https://www.solidjs.com/tutorial/bindings_directives
const clickOutside = (el, accessor) => {
  const onClick = (e) => !el.contains(e.target) && accessor()?.();
  document.body.addEventListener("click", onClick);

  onCleanup(() => document.body.removeEventListener("click", onClick));
};

export const Dropdown: ParentComponent<DropdownProps> = (props) => {
  const [isOpen, setIsOpen] = createSignal(false);

  const toggle = () => {
    setIsOpen(!isOpen());
  };

  const close = () => {
    setIsOpen(false);
  };

  const handleTriggerClick = (e: MouseEvent) => {
    e.stopPropagation();
    toggle();
  };

  return (
    <div class={props.class || "dropdown"} use:clickOutside={() => setIsOpen(false)}>
      <div onClick={handleTriggerClick}>
        {props.trigger}
      </div>
      <div 
        class={`dropdown-content ${props.contentClass || ''} ${isOpen() ? 'show' : ''} ${props.alignRight ? 'align-right' : ''}`}
        onClick={close}
      >
        {props.children}
      </div>
    </div>
  );
};
