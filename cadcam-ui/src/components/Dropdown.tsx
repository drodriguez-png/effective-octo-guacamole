import { createSignal, JSX, ParentComponent } from 'solid-js';

interface DropdownProps {
  trigger: JSX.Element;
  class?: string;
  contentClass?: string;
  alignRight?: boolean;
}

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
    <div class={props.class || "dropdown"}>
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