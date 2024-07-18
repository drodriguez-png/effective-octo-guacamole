import {
  Component,
  For,
  Index,
  Match,
  Show,
  Switch,
  createResource,
  createSignal,
  onCleanup,
} from "solid-js";
import { FiInfo } from "solid-icons/fi";
import { NestInfo } from "./components/Nest";

const getMachines = async () => {
  const response = await fetch(`/api/machines`);
  return response.json();
};

const getPrograms = async (machine: string) => {
  if (!machine) return;

  localStorage.setItem("machine", machine);

  const response = await fetch(`/api/${machine}`);
  return response.json();
};

export const BatchAssign: Component = () => {
  const [machine, setMachine] = createSignal(
    localStorage.getItem("machine") || "",
  );
  const [info, showInfo] = createSignal<string | null>(null);

  const [machines, { refetch }] = createResource(getMachines);
  const [programs] = createResource(machine, getPrograms);

  const machinesListTimer = setInterval(() => {
    refetch();
  }, 60 * 1000);
  onCleanup(() => clearInterval(machinesListTimer));

  return (
    <div class="w-3/5 min-w-96 overflow-hidden rounded-2xl">
      <select value={machine()} class="m-2 rounded-lg bg-slate-300 p-2">
        <For each={machines()}>
          {(item) => (
            <option value={item} onChange={() => setMachine(item)}>
              {item}
            </option>
          )}
        </For>
      </select>
      <section>
        <Show when={programs.loading}>
          <p class="col-span-full row-span-full place-self-center">
            Fetching...
          </p>
        </Show>
        <Switch>
          <Match when={!machine()}>
            <p class="col-span-full place-self-center">No machine selected</p>
          </Match>
          <Match when={programs.error}>
            <p class="col-span-full place-self-center">
              Error fetching programs
            </p>
            <p class="cols-span-full place-self-center font-mono">
              {programs.error}
            </p>
          </Match>
          <Match when={programs()}>
            <div
              class="m-4 overflow-auto shadow-md sm:rounded-lg"
              // style={{ height: "80vh" }}
            >
              <table class="w-full text-sm text-gray-500">
                <thead class="sticky top-0 z-10 bg-gradient-to-tr from-amber-300 to-orange-400 text-xs uppercase text-gray-700">
                  <tr>
                    <th scope="col" class="px-6 py-3"></th>
                    <th scope="col" class="px-6 py-3">
                      Program
                    </th>
                    <th scope="col" class="px-6 py-3">
                      Runtime
                    </th>
                    <th scope="col" class="px-6 py-3">
                      --not needed
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <Index each={programs()}>
                    {(item) => (
                      <>
                        <tr
                          class="border-t hover:bg-gray-100"
                          onClick={() => showInfo(item())}
                        >
                          <th class="px-6 py-4">
                            <FiInfo
                              class="rounded ring-offset-8 hover:ring-2"
                              onClick={(e) => {
                                e.stopPropagation();
                                showInfo(item());
                              }}
                            />
                          </th>
                          <th
                            scope="row"
                            class="whitespace-nowrap px-6 py-4 font-medium text-gray-900"
                          >
                            {item()}
                          </th>
                          <td class="px-6 py-4">data1</td>
                          <td class="px-6 py-4">data2</td>
                        </tr>
                      </>
                    )}
                  </Index>
                </tbody>
              </table>
              <Show when={info()}>
                <NestInfo
                  name={info() || ""}
                  onCloseEvent={() => showInfo(null)}
                />
              </Show>
            </div>
          </Match>
        </Switch>
      </section>
    </div>
  );
};
