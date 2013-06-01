// This is based on the Dart implementation of the Richards benchmark from:
//
//    http://www.cl.cam.ac.uk/~mr10/Bench.html
//
// The benchmark was originally implemented in BCPL by
// Martin Richards.

import 'stdio.dart';

/**
 * A simple package of data that is manipulated by the tasks.  The exact
 * layout of the payload data carried by a packet is not importaint, and
 * neither is the nature of the work performed on packets by the tasks.
 * Besides carrying data, packets form linked lists and are hence used both
 * as data and worklists.
 */
class Packet {
  Packet link; // The tail of the linked list of packets.
  int id;      // An ID for this packet.
  int kind;    // The type of this packet.
  int a1;

  List a2;
}

/**
 * A 16-bit State represented by a List of ints as Start doesn't support bit
 * operations.
 */
class State {
  List bits;
}

/**
 * A task control block manages a task and the queue of work packages
 * associated with it.
 */
class TaskControlBlock {
  TaskControlBlock link;
  int id;       // The id of this block.
  int priority; // The priority of this block.
  Packet queue; // The queue of packages to be processed by the task.
  var task;
  State state;
}

/**
 * A scheduler can be used to schedule a set of tasks based on their relative
 * priorities.  Scheduling is done by maintaining a list of task control
 * blocks which holds tasks and the data queue they are processing.
 */
class Scheduler {
  int queueCount;
  int holdCount;
  TaskControlBlock currentTcb;
  int currentId;
  TaskControlBlock list;
  List blocks;
}

/**
 * An idle task doesn't do any work itself but cycles control between the two
 * device tasks.
 */
class IdleTask /*extends Task*/ {
  Scheduler scheduler;
  State v1;  // A seed value that controls how the device tasks are scheduled.
  int count; // The number of times this task should be scheduled.
}

/**
 * A task that suspends itself after each time it has been run to simulate
 * waiting for data from an external device.
 */
class DeviceTask /*extends Task*/ {
  Scheduler scheduler;
  Packet v1;
}

/**
 * A task that manipulates work packets.
 */
class WorkerTask /*extends Task*/ {
  Scheduler scheduler;
  int v1; // A seed used to specify how work packets are manipulated.
  int v2; // Another seed used to specify how work packets are manipulated.
}

/**
 * A task that manipulates work packets and then suspends itself.
 */
class HandlerTask /*extends Task*/ {
  Scheduler scheduler;
  Packet v1;
  Packet v2;
}

/// The task is running and is currently scheduled.
State STATE_RUNNING;

/// The task has packets left to process.
State STATE_RUNNABLE;

/// The task is not currently running. The task is not blocked as such and may
/// be started by the scheduler.
State STATE_SUSPENDED;

/// The task is blocked and cannot be run until it is explicitly released.
State STATE_HELD;

/// SUSPENDED or RUNNABLE
State STATE_SUSPENDED_RUNNABLE;

/// RUNNING, SUSPENDED, or RUNNABLE
State STATE_NOT_HELD;

// Globals to hold return values for correspondingly named functions.
State new_State_result;
State State_and_result;
State State_or_result;
State State_rshift_result;
int State_equals_result;

int and_result;
int or_result;

TaskControlBlock Scheduler_release_result;
TaskControlBlock Scheduler_holdCurrent_result;
TaskControlBlock Scheduler_suspendCurrent_result;
TaskControlBlock Scheduler_queue_result;

TaskControlBlock TaskControlBlock_run_result;
TaskControlBlock TaskControlBlock_checkPriorityAdd_result;
int TaskControlBlock_isHeldOrSuspended_result;

TaskControlBlock Task_run_result;

Packet new_Packet_result;
Packet Packet_addTo_result;

void State_set(State state, int runnable, int suspended, int held) {
  int i;
  state.bits = new List(16);
  state.bits[0] = runnable;
  state.bits[1] = suspended;
  state.bits[2] = held;
  i = 3;
  while (i < 16) {
    state.bits[i] = 0;
    i = i + 1;
  }
}

void new_State(int runnable, int suspended, int held) {
  State s;
  s = new State();
  State_set(s, runnable, suspended, held);
  new_State_result = s;
}

void and(int i, int j) {
  and_result = 0;
  if (i != 0) {
    if (j != 0) {
      and_result = 1;
    }
  }
}

void or(int i, int j) {
  or_result = 1;
  if (i == 0) {
    if (j == 0) {
      or_result = 0;
    }
  }
}

void State_and(State s1, State s2) {
  State s;
  int i;

  s = new State();
  s.bits = new List(16);
  i = 0;
  while (i < 16) {
    and(s1.bits[i], s2.bits[i]);
    s.bits[i] = and_result;
    i = i + 1;
  }
  State_and_result = s;
}

void State_or(State s1, State s2) {
  State s;
  int i;

  s = new State();
  s.bits = new List(16);
  i = 0;
  while (i < 16) {
    or(s1.bits[i], s2.bits[i]);
    s.bits[i] = or_result;
    i = i + 1;
  }
  State_or_result = s;
}

void State_rshift(State s1) {
  State s;
  int i;

  s = new State();
  s.bits = new List(16);

  i = 0;
  while (i < 15) {
    s.bits[i] = s1.bits[i+1];
    i = i + 1;
  }
  s.bits[15] = 0;

  State_rshift_result = s;
}

void State_equals(State s1, State s2) {
  int i;
  int miss;

  i = 0;
  miss = 0;
  while (i < 16) {
    if (s1.bits[i] != s2.bits[i]) {
      miss = miss + 1;
    }
    i = i + 1;
  }

  if (miss > 0) {
    State_equals_result = 0;
  } else {
    State_equals_result = 1;
  }
}

void initializeState() {
  new_State(0, 0, 0);
  STATE_RUNNING = new_State_result;

  new_State(1, 0, 0);
  STATE_RUNNABLE = new_State_result;

  new_State(0, 1, 0);
  STATE_SUSPENDED = new_State_result;

  new_State(0, 0, 1);
  STATE_HELD = new_State_result;

  new_State(1, 1, 0);
  STATE_SUSPENDED_RUNNABLE = new_State_result;

  new_State(1, 1, 0);
  STATE_NOT_HELD = new_State_result;
}

void Packet_initialize(Packet packet, Packet link, int id, int kind) {
  packet.link = link;
  packet.id = id;
  packet.kind = kind;
  packet.a1 = 0;
  packet.a2 = new List(/*DATA_SIZE*/ 4);
}

void new_Packet(Packet link, int id, int kind) {
  Packet p;
  p = new Packet();
  Packet_initialize(p, link, id, kind);
  new_Packet_result = p;
}

/// Add this packet to the end of a worklist, and return the worklist.
void Packet_addTo(Packet packet, Packet queue) {
  Packet peek;
  Packet next;

  packet.link = null;
  if (queue == null) {
    Packet_addTo_result = packet;
  } else {
    next = queue;
    peek = next.link;
    while (peek != null) {
      next = peek;
      peek = next.link;
    }
    next.link = packet;
    Packet_addTo_result = queue;
  }
}


void TaskControlBlock_initialize(TaskControlBlock tcb, TaskControlBlock link,
                            int id, int priority, Packet queue, var task) {
  tcb.link = link;
  tcb.id = id;
  tcb.priority = priority;
  tcb.queue = queue;
  tcb.task = task;

  if (queue == null) {
    tcb.state = STATE_SUSPENDED;
  } else {
    tcb.state = STATE_SUSPENDED_RUNNABLE;
  }
}

void TaskControlBlock_setRunning(TaskControlBlock tcb) {
  tcb.state = STATE_RUNNING;
}

void TaskControlBlock_markAsNotHeld(TaskControlBlock tcb) {
  State_and(tcb.state, STATE_NOT_HELD);
  tcb.state = State_and_result;
}

void TaskControlBlock_markAsHeld(TaskControlBlock tcb) {
  State_or(tcb.state, STATE_HELD);
  tcb.state = State_or_result;
}

void TaskControlBlock_isHeldOrSuspended(TaskControlBlock tcb) {
  TaskControlBlock_isHeldOrSuspended_result = 0;
  if (tcb.state.bits[2] != 0) {
    TaskControlBlock_isHeldOrSuspended_result = 1;
  }
  State_equals(tcb.state, STATE_SUSPENDED);
  if (State_equals_result > 0) {
    TaskControlBlock_isHeldOrSuspended_result = 1;
  }
}

void TaskControlBlock_markAsSuspended(TaskControlBlock tcb) {
  State_or(tcb.state, STATE_SUSPENDED);
  tcb.state = State_or_result;
}

void TaskControlBlock_markAsRunnable(TaskControlBlock tcb) {
  State_or(tcb.state, STATE_RUNNABLE);
  tcb.state = State_or_result;
}

/**
 * Adds a packet to the worklist of this block's task, marks this as
 * runnable if necessary, and returns the next runnable object to run
 * (the one with the highest priority).
 */
void TaskControlBlock_checkPriorityAdd(TaskControlBlock tcb,
                                       TaskControlBlock task,
                                       Packet packet) {
  if (tcb.queue == null) {
    tcb.queue = packet;
    TaskControlBlock_markAsRunnable(tcb);
    if (tcb.priority > task.priority) {
      TaskControlBlock_checkPriorityAdd_result = tcb;
    } else {
      TaskControlBlock_checkPriorityAdd_result = task;
    }
  } else {
    Packet_addTo(packet, tcb.queue);
    tcb.queue = Packet_addTo_result;
    TaskControlBlock_checkPriorityAdd_result = task;
  }
}

/**
 * Block the currently executing task and return the next task control block
 * to run.  The blocked task will not be made runnable until it is explicitly
 * released, even if new work is added to it.
 */
void Scheduler_holdCurrent(Scheduler scheduler) {
  scheduler.holdCount = scheduler.holdCount + 1;
  TaskControlBlock_markAsHeld(scheduler.currentTcb);
  Scheduler_holdCurrent_result = scheduler.currentTcb.link;
}

/// Release a task that is currently blocked and return the next block to run.
void Scheduler_release(Scheduler scheduler, int id) {
  TaskControlBlock tcb;

  tcb = scheduler.blocks[id];
  if (tcb == null)  {
    Scheduler_release_result = tcb;
  } else {
    TaskControlBlock_markAsNotHeld(tcb);
    if (tcb.priority > scheduler.currentTcb.priority) {
      Scheduler_release_result = tcb;
    } else {
      Scheduler_release_result = scheduler.currentTcb;
    }
  }
}

/**
 * Suspend the currently executing task and return the next task
 * control block to run.
 * If new work is added to the suspended task it will be made runnable.
 */
void Scheduler_suspendCurrent(Scheduler scheduler) {
  TaskControlBlock_markAsSuspended(scheduler.currentTcb);
  Scheduler_suspendCurrent_result = scheduler.currentTcb;
}

/**
 * Add the specified packet to the end of the worklist used by the task
 * associated with the packet and make the task runnable if it is currently
 * suspended.
 */
void Scheduler_queue(Scheduler scheduler, Packet packet) {
  TaskControlBlock t;

  t = scheduler.blocks[packet.id];
  if (t == null) {
    Scheduler_queue_result = t;
  } else {
    scheduler.queueCount = scheduler.queueCount + 1;
    packet.link = null;
    packet.id = scheduler.currentId;
    TaskControlBlock_checkPriorityAdd(t, scheduler.currentTcb, packet);
    Scheduler_queue_result = TaskControlBlock_checkPriorityAdd_result;
  }
}

void IdleTask_initialize(IdleTask task, Scheduler scheduler,
                         State v1, int count) {
  task.scheduler = scheduler;
  task.v1 = v1;
  task.count = count;
}

void IdleTask_run(IdleTask task, Packet packet) {
  task.count = task.count - 1;
  if (task.count == 0) {
    Scheduler_holdCurrent(task.scheduler);
    Task_run_result = Scheduler_holdCurrent_result;
  } else {
    if ((task.v1.bits[0]) == 0) {
      State_rshift(task.v1);
      task.v1 = State_rshift_result;
      Scheduler_release(task.scheduler, /*ID_DEVICE_A*/ 4);
      Task_run_result = Scheduler_release_result;
    } else {
      State_rshift(task.v1);
      task.v1 = State_rshift_result;
      // v1 = v1 xor 0xD008
      task.v1.bits[3] = 1 - task.v1.bits[3];
      task.v1.bits[12] = 1 - task.v1.bits[12];
      task.v1.bits[14] = 1 - task.v1.bits[14];
      task.v1.bits[15] = 1 - task.v1.bits[15];
      Scheduler_release(task.scheduler, /*ID_DEVICE_B*/ 5);
      Task_run_result = Scheduler_release_result;
    }
  }
}

void DeviceTask_initialize(DeviceTask task, Scheduler scheduler) {
  task.scheduler = scheduler;
}

void DeviceTask_run(DeviceTask task, Packet packet) {
  Packet v;

  if (packet == null) {
    if (task.v1 == null) {
      Scheduler_suspendCurrent(task.scheduler);
      Task_run_result = Scheduler_suspendCurrent_result;
    } else {
      v = task.v1;
      task.v1 = null;
      Scheduler_queue(task.scheduler, v);
      Task_run_result = Scheduler_queue_result;
    }
  } else {
    task.v1 = packet;
    Scheduler_holdCurrent(task.scheduler);
    Task_run_result = Scheduler_holdCurrent_result;
  }
}

void WorkerTask_initialize(WorkerTask task, Scheduler scheduler,
                      int v1, int v2) {
  task.scheduler = scheduler;
  task.v1 = v1;
  task.v2 = v2;
}

void WorkerTask_run(WorkerTask task, Packet packet) {
  int i;

  if (packet == null) {
    Scheduler_suspendCurrent(task.scheduler);
    Task_run_result = Scheduler_suspendCurrent_result;
  } else {
    if (task.v1 == /*ID_HANDLER_A*/ 2) {
      task.v1 = /*ID_HANDLER_B*/ 3;
    } else {
      task.v1 = /*ID_HANDLER_A*/ 2;
    }
    packet.id = task.v1;
    packet.a1 = 0;
    i = 0;
    while (i < /*DATA_SIZE*/ 4) {
      task.v2 = task.v2 + 1;
      if (task.v2 > 26)  { task.v2 = 1; }
      packet.a2[i] = task.v2;
      i = i + 1;
    }
    Scheduler_queue(task.scheduler, packet);
    Task_run_result = Scheduler_queue_result;
  }
}

void HandlerTask_initialize(HandlerTask task, Scheduler scheduler) {
  task.scheduler = scheduler;
}

void HandlerTask_run(HandlerTask task, Packet packet) {
  int count;
  Packet v;
  if (packet != null) {
    if (packet.kind == /*KIND_WORK*/ 1) {
      Packet_addTo(packet, task.v1);
      task.v1 = Packet_addTo_result;
    } else {
      Packet_addTo(packet, task.v2);
      task.v2 = Packet_addTo_result;
    }
  }
  if (task.v1 != null) {
    count = task.v1.a1;

    if (count < /*DATA_SIZE*/ 4) {
      if (task.v2 != null) {
        v = task.v2;
        task.v2 = task.v2.link;
        v.a1 = task.v1.a2[count];
        task.v1.a1 = count + 1;
        Scheduler_queue(task.scheduler, v);
        Task_run_result = Scheduler_queue_result;
      } else {
        Scheduler_suspendCurrent(task.scheduler);
        Task_run_result = Scheduler_suspendCurrent_result;
      }
    } else {
      v = task.v1;
      task.v1 = task.v1.link;
      Scheduler_queue(task.scheduler, v);
      Task_run_result = Scheduler_queue_result;
    }
  } else {
    Scheduler_suspendCurrent(task.scheduler);
    Task_run_result = Scheduler_suspendCurrent_result;
  }
}

void Task_run(var task, Packet packet) {
  Task_run_result = null;
  if (task is IdleTask) {
    IdleTask_run(task, packet);
  } else {
    if (task is DeviceTask) {
      DeviceTask_run(task, packet);
    } else {
      if (task is WorkerTask) {
        WorkerTask_run(task, packet);
      } else {
        if (task is HandlerTask) {
          HandlerTask_run(task, packet);
        } else {
          // assert(0);
        }
      }
    }
  }
}

/// Runs this task, if it is ready to be run, and returns the next task to
/// run.
void TaskControlBlock_run(TaskControlBlock tcb) {
  Packet packet;
  State_equals(tcb.state, STATE_SUSPENDED_RUNNABLE);
  if (State_equals_result != 0) {
    packet = tcb.queue;
    tcb.queue = packet.link;
    if (tcb.queue == null) {
      tcb.state = STATE_RUNNING;
    } else {
      tcb.state = STATE_RUNNABLE;
    }
  } else {
    packet = null;
  }
  Task_run(tcb.task, packet);
  TaskControlBlock_run_result = Task_run_result;
}

void Scheduler_initialize(Scheduler scheduler) {
  scheduler.queueCount = 0;
  scheduler.holdCount = 0;
  scheduler.currentTcb = null;
  scheduler.currentId = 0;
  scheduler.list = null;
  scheduler.blocks = new List(/*NUMBER_OF_IDS*/ 6);
}

/// Add the specified task to this scheduler.
void Scheduler_addTask(Scheduler scheduler, int id, int priority,
                       Packet queue, var task) {
  scheduler.currentTcb = new TaskControlBlock();

  TaskControlBlock_initialize(scheduler.currentTcb, scheduler.list, id,
                              priority, queue, task);
  scheduler.list = scheduler.currentTcb;
  scheduler.blocks[id] = scheduler.currentTcb;
}

/// Add an idle task to this scheduler.
/// Add the specified task and mark it as running.
void Scheduler_addRunningTask(Scheduler scheduler, int id, int priority,
                              Packet queue, var task) {
  Scheduler_addTask(scheduler, id, priority, queue, task);
  TaskControlBlock_setRunning(scheduler.currentTcb);
}

void Scheduler_addIdleTask(Scheduler scheduler, int id, int priority,
                           Packet queue, int count) {
  IdleTask idleTask;

  idleTask = new IdleTask();
  IdleTask_initialize(idleTask, scheduler, STATE_RUNNABLE, count);
  Scheduler_addRunningTask(scheduler, id, priority, queue, idleTask);
}

/// Add a work task to this scheduler.
void Scheduler_addWorkerTask(Scheduler scheduler, int id, int priority,
                             Packet queue) {
  WorkerTask workerTask;

  workerTask = new WorkerTask();
  WorkerTask_initialize(workerTask, scheduler, /*ID_HANDLER_A*/ 2, 0);
  Scheduler_addTask(
          scheduler,
          id,
          priority,
          queue,
          workerTask);
}

/// Add a handler task to this scheduler.
void Scheduler_addHandlerTask(Scheduler scheduler, int id, int priority,
                              Packet queue) {
  HandlerTask handlerTask;

  handlerTask = new HandlerTask();
  HandlerTask_initialize(handlerTask, scheduler);
  Scheduler_addTask(scheduler, id, priority, queue, handlerTask);
}

/// Add a handler task to this scheduler.
void Scheduler_addDeviceTask(Scheduler scheduler, int id, int priority,
                             Packet queue) {
  DeviceTask deviceTask;

  deviceTask = new DeviceTask();
  DeviceTask_initialize(deviceTask, scheduler);
  Scheduler_addTask(scheduler, id, priority, queue, deviceTask);
}

/// Execute the tasks managed by this scheduler.
void Scheduler_schedule(Scheduler scheduler) {
  scheduler.currentTcb = scheduler.list;
  while (scheduler.currentTcb != null) {
    TaskControlBlock_isHeldOrSuspended(scheduler.currentTcb);
    if (TaskControlBlock_isHeldOrSuspended_result != 0) {
      scheduler.currentTcb = scheduler.currentTcb.link;
    } else {
      scheduler.currentId = scheduler.currentTcb.id;
      TaskControlBlock_run(scheduler.currentTcb);
      scheduler.currentTcb = TaskControlBlock_run_result;
    }
  }
}

void run() {
  Scheduler scheduler;

  scheduler = new Scheduler();
  Scheduler_initialize(scheduler);
  Scheduler_addIdleTask(scheduler, /*ID_IDLE*/ 0, 0, null, /*COUNT*/ 1000);

  new_Packet(null, /*ID_WORKER*/ 1, /*KIND_WORK*/ 1);
  new_Packet(new_Packet_result, /*ID_WORKER*/ 1, /*KIND_WORK*/ 1);

  Scheduler_addWorkerTask(scheduler, /*ID_WORKER*/ 1, 1000,
                          new_Packet_result);

  new_Packet(null, /*ID_DEVICE_A*/ 4, /*KIND_DEVICE*/ 0);
  new_Packet(new_Packet_result, /*ID_DEVICE_A*/ 4, /*KIND_DEVICE*/ 0);
  new_Packet(new_Packet_result, /*ID_DEVICE_A*/ 4, /*KIND_DEVICE*/ 0);
  Scheduler_addHandlerTask(scheduler, /*ID_HANDLER_A*/ 2, 2000,
                           new_Packet_result);

  new_Packet(null, /*ID_DEVICE_B*/ 5, /*KIND_DEVICE*/ 0);
  new_Packet(new_Packet_result, /*ID_DEVICE_B*/ 5, /*KIND_DEVICE*/ 0);
  new_Packet(new_Packet_result, /*ID_DEVICE_B*/ 5, /*KIND_DEVICE*/ 0);
  Scheduler_addHandlerTask(scheduler, /*ID_HANDLER_B*/ 3, 3000,
                           new_Packet_result);

  Scheduler_addDeviceTask(scheduler, /*ID_DEVICE_A*/ 4, 4000, null);

  Scheduler_addDeviceTask(scheduler, /*ID_DEVICE_B*/ 5, 5000, null);

  Scheduler_schedule(scheduler);

  WriteLong(scheduler.queueCount);
  WriteLong(scheduler.holdCount);
  WriteLine();
}

void main() {
  initializeState();
  run();
}