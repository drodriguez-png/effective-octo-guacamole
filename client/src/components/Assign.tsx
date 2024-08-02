import { FiX, FiAlertTriangle } from "solid-icons/fi";
import { ImSpinner8 } from "solid-icons/im";
import {
  Component,
  createResource,
  For,
  Show,
  Switch,
  Match,
  createSignal,
  createEffect,
} from "solid-js";
import { Portal } from "solid-js/web";
import { Batch } from "../api/batch";

type Props = {
  name: string;
  onCloseEvent: () => void;
};

enum State {
  Initiated = "Initiated",
  Processing = "Processing",
  Complete = "Complete",
  Cancelled = "Cancelled",
}

const getBatches = async (nest: string) => {
  const response = await fetch(`/api/batches/${nest}`);
  return response.json();
};

export const NestAssign: Component<Props> = (props: Props) => {
  const name = () => props.name;
  const [batches] = createResource<Batch[], any>(name, getBatches);
  const [state, setState] = createSignal(State.Initiated);
  const [batch, setBatch] = createSignal("");

  createEffect(() => {
    if (!batch() && batches()) {
      setBatch(batches()?.at(0)?.id ?? "");
    }
  });

  createEffect(async () => {
    // do not inline this function or the effect is called on batch() changes
    await fetch(`/api/nest/${name()}`, {
      method: "POST",
      body: JSON.stringify({
        batch: batch(),
        state: state(),
      }),
      headers: { "Content-type": "application/json; charset=UTF-8" },
    });

    switch (state()) {
      case State.Initiated:
      case State.Processing:
        break;
      case State.Complete:
      case State.Cancelled:
        props.onCloseEvent();
        break;
    }
  });

  return (
    <Portal>
      <div
        class="absolute inset-0 z-40 h-full w-full bg-slate-500 opacity-75"
        onClick={() => setState(State.Cancelled)}
      ></div>
      <dialog
        class="fixed inset-0 z-50 overflow-auto rounded-lg border backdrop-blur-sm"
        open={true}
      >
        <Show when={batches.loading}>
          <main class="rounded-lg border-4 bg-gradient-to-tr from-sky-300 to-teal-400 p-4">
            <div class="flex items-center space-x-2 font-sans">
              <span>
                <ImSpinner8 class="animate-spin" />
              </span>
              <p>fetching nest data...</p>
            </div>
          </main>
        </Show>
        <Switch>
          <Match when={batches.error}>
            <main class="rounded-lg border-4 border-rose-500 bg-gradient-to-tr from-red-200 to-red-500 p-4">
              <div class="flex items-center space-x-2 font-sans">
                <span>
                  <FiAlertTriangle class="size-5 animate-pulse" />
                </span>
                <p>failed to retrieve nest data</p>
              </div>
            </main>
          </Match>
          <Match when={batches()}>
            <header class="flex items-center border-b-2 bg-gradient-to-tr from-amber-300 to-orange-400 p-2">
              <p class="grow text-lg">
                <span class="select-all">{name()}</span>
              </p>
              <FiX
                class="rounded hover:ring-2"
                onClick={() => setState(State.Cancelled)}
              />
            </header>
            <main class="grid grid-cols-1 divide-y p-4">
              <Switch>
                <Match when={state() === State.Initiated}>
                  <div>
                    <select
                      value={batch()}
                      onChange={(e) =>
                        setBatch((e.currentTarget as HTMLSelectElement).value)
                      }
                      class="m-2 rounded-lg border-black bg-gray-200 p-2"
                    >
                      <For each={batches()}>
                        {(item) => (
                          <option class="hover:bg-slate-200" value={item.id}>
                            {item.id}
                          </option>
                        )}
                      </For>
                    </select>
                  </div>
                </Match>
                <Match when={state() === State.Processing}>
                  <div>
                    <p>
                      Ready to process {name()} using batch {batch()}
                    </p>
                    <p>Code is at your machine and ready to be processed.</p>
                  </div>
                </Match>
              </Switch>
            </main>
            <footer class="border-t-2 px-4 py-2">
              <Switch>
                <Match when={state() === State.Initiated}>
                  <button
                    class="rounded bg-sky-500 px-2 py-1"
                    onClick={() => setState(State.Processing)}
                  >
                    Move to processing
                  </button>
                </Match>
                <Match when={state() === State.Processing}>
                  <button
                    class="mx-2 rounded bg-sky-500 px-2 py-1"
                    onClick={() => setState(State.Initiated)}
                  >
                    Back
                  </button>
                  <button
                    class="mx-2 rounded bg-sky-500 px-2 py-1"
                    onClick={() => setState(State.Complete)}
                  >
                    Nest is complete
                  </button>
                </Match>
              </Switch>
              <button
                class="mx-2 rounded bg-sky-500 px-2 py-1"
                onClick={() => setState(State.Cancelled)}
              >
                Cancel
              </button>
            </footer>
          </Match>
        </Switch>
      </dialog>
    </Portal>
  );
};
