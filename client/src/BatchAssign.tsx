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
import { cuttingTimeStr } from "./utils";

type Program = {
  program: string;
  cuttingTime: number;
  repeats: number;
};

const getMachines = async () => {
  const response = await fetch(`/api/machines`);
  return response.json();
};

const getPrograms = async (machine: string) => {
  if (!machine) return;

  console.log(`Setting machine to ${machine}`);
  localStorage.setItem("machine", machine);

  const response = await fetch(`/api/${machine}`);
  return response.json();
};

export const BatchAssign: Component = () => {
  // TODO: should state migrate to a context manager
  const [machine, setMachine] = createSignal(
    localStorage.getItem("machine") || "",
  );
  const [info, showInfo] = createSignal<string | null>(null);

  const [machines, { refetch: fetchMachines }] = createResource(getMachines);
  const [programs, { refetch: fetchPrograms }] = createResource<Program[], any>(
    machine,
    getPrograms,
  );
  const timer = setInterval(
    () => {
      fetchMachines();
      fetchPrograms();
    },
    5 * 60 * 1000,
  );
  onCleanup(() => clearInterval(timer));

  return (
    <div class="w-3/5 min-w-96 overflow-hidden rounded-2xl bg-gradient-to-tr from-amber-200 to-orange-400">
      <select
        value={machine()}
        onClick={() => fetchMachines()}
        onChange={(e) =>
          setMachine((e.currentTarget as HTMLSelectElement).value)
        }
        class="m-2 rounded-lg bg-gray-200 p-2"
      >
        <For each={machines()}>
          {(item) => (
            <option class="hover:bg-slate-200" value={item}>
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
                <thead class="sticky top-0 z-10 bg-gradient-to-tr from-amber-100 to-amber-300 text-xs uppercase text-gray-700">
                  <tr>
                    <th scope="col" class="px-6 py-3"></th>
                    <th scope="col" class="px-6 py-3">
                      Program
                    </th>
                    <th scope="col" class="px-6 py-3">
                      Runtime
                    </th>
                    <th scope="col" class="px-6 py-3">
                      Repeats
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <Index each={programs()}>
                    {(item) => (
                      <>
                        <tr
                          class="border-t bg-slate-100 hover:bg-slate-300"
                          onClick={() => showInfo(item().program)}
                        >
                          <th class="px-6 py-4">
                            <FiInfo
                              class="rounded ring-offset-8 hover:ring-2"
                              onClick={(e) => {
                                e.stopPropagation();
                                showInfo(item().program);
                              }}
                            />
                          </th>
                          <th
                            scope="row"
                            class="whitespace-nowrap px-6 py-4 font-medium text-gray-900"
                          >
                            {item().program}
                          </th>
                          <td class="px-6 py-4">
                            {cuttingTimeStr(item().cuttingTime)}
                          </td>
                          <td class="px-6 py-4">{item().repeats}</td>
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
