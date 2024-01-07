﻿unit Settings;

{$savepcu false} //TODO

// Я разделяю в этой программе 3 вида пространства:
// - Графическое: 1 пиксель экрана это 1х1 графического пространства
// - Логическое: Весь рисунок Mandelbrot помещается в -2..+2 логического пространства (горизонтально и вертикально), независимо от графического масштаба
// - Пространство блока/точек: Каждый блок любого масштаба хранит block_w*block_w точек, каждая из которых просчитывается отдельно

// Если в блоках слишком мало точек, получается много отдельных обращений к GPU
// А если слишном много - значительная часть просчитываемых точек
// (для которых надо VRAM и время GPU) может быть за пределами экрана
const block_w_pow = 9;
const block_w = 1 shl block_w_pow; // 512

// Просчитываемые в любой момент блоки хранит в VRAM (личной памяти GPU)
// Для 1080p надо чуть больше 1.25 GB при поверхностном приближении
// (чем глубже - тем больше точность расчётов и тем больше надо памяти)
// Но если VRAM у системы мало (к примеру, браузер много скушал),
// драйвера могут крашнутся при слишком большом использовании VRAM данной программой
// Смотрите в диспетчер задач чтобы выставить сколько вы можете себе позволить
const max_VRAM = 838860800; // 800 MB
// Если VRAM заканчивается - старые блоки отправляет в RAM (в обычную оперативную память)
// Пока что 0, что значит старые блоки в VRAM уничтожаются как только перестают помещаться
const max_RAM = 0;// 4294967296; // 4 GB
// А если заканчивается и RAM - самые старые блоки отправляет на диск
// Если у вас медленный диск, есть смысл оставить тут 0
// Но если включать - надо сразу установить max_RAM>=max_VRAM
// Потому что блоки не могут прыгнуть сразу из VRAM на диск или назад
const max_drive_space = 0;// 10737418240; // 10 GB

// Сторона блока в логическом пространстве это всегда степень двойки (обычно отрицательная степень)
// Если scale_pow_shift=0, размер блоков в логическом пространстве будет выбирать так,
// чтобы на каждый пиксель экрана приходилась хотя бы область из 1x1 точек в соответствующем блоке
// Когда отдаляют достаточно чтобы в пиксель поместилась область из 2x2 точек, масштаб блоков переключается на следующий
// Если scale_pow_shift=-1, на каждый пиксель придётся хотя бы 2x2 точек, и всегда меньше 4x4
// Значение -1 значительно улучшает визуал, но уже требует в 4 раза больше памяти и производительности
// Желательно дальше не понижать без очень мощного компьютера
// Иначе просчитывать будет только блоки в центре экрана (если закончится VRAM)
const scale_pow_shift = -1; // <=0
// Блок максимального размера занимает в логическом пространстве область 2х2
// Таким образом вся просчитываемая область (4х4 вокруг точки 0;0) разбита на минимум 4 блока, по 1 на угол
// При приближении камеры каждый из этих угловых блоков будет далее разбивать на 4 меньших блока
// Не менять, эта константа много где неявно задана, самим алгоритмом
const max_block_scale_pow = 1;

// Каждая точка в каждом блоке хранит текущее состояние
// (z и номер шага) рекуррентной функции "z_next(z) = z*z + c"
// Где "z" это предыдущее значение (изначально 0), а "c" это "x+y*i"
// (комплексное число представляющее координаты точки в логическом пространстве)
// На экране рисует только кол-во шагов этой функции (ещё_считает=белый; 0 шагов=чёрный; остальное радугой)
// А в отдельном от графики потоке выполнения (класс Blocks.BlockUpdater)
// циклически берёт блоки текущего масштаба и просчитывает их на несколько шагов вперёд
// Максимум за 1 итерацию обработки может выполнить max_steps_at_once шагов для всех точек
// Это ограничение на всякий случай, чтобы Blocks.BlockUpdater не застряло на несколько секунд
// (от такого застревания может даже полностью перезапустится графический драйвер)
// Но это и так не должно происходить, потому что количество шагов и так сбрасывается к 1 при смене текущих блоков
const max_steps_at_once = 1024;
// Все блоки можно обрабатывать по-очереди или параллельно
// Чтобы достичь большОй параллельности - надо выделить много ресурсов в
// виде OpenCL.cl_command_queue (личные данные каждого потока выполнения GPU)
// Но если обрабатывать все блоки один за другим, GPU будет повторно оставаться
// без работы на короткие промежутки времени, между обработками блоков
// Поэтому одновременно обрабатывать будет не больше чем max_parallel_blocks блоков
const max_parallel_blocks = 2;
// Чем больше шагов - тем меньшая доля времени будет потрачена на синхронизацию и т.п. между обработками
// Но если обработка блоков использует GPU слишком эффективно,
// она заберёт все ресурсы у системы и графика начнёт лагать
// Поэтому кол-во шагов в 1 обработке меняет в диапазоне 1..max_steps_at_once,
// так чтобы 1 обработка заменяла примерно столько секунд:
const target_step_time_seconds = 0.050;
//TODO Может делать несколько запусков kernel-а подряд, чтобы у потока графики было больше шансов получить нужное ему время GPU...

// Комплексное число z на каждом шаге представляет как 2 компоненты (PointComponents.pas и point_component в MandelbrotSampling.cl)
// Каждая компонента это число число с фиксированной точкой (fixed-point number)
// Это всё число разделено на несколько слов типа UInt32 (чтобы обрабатывать сразу кучу битов каждой операцией процессора)
// Кол-во слов выбирается в CameraDef.CameraPos.GetWordCount, исходя из нужного кол-ва бит для текущего масштаба
// 
// Последним шагом считается шаг где |z_next|>2
// Модуль комплексной точки "x+y*i" это модуль (длина) вектора (x;y), то есть "Sqrt(x.Sqr+y.Sqr)"
// На шаге=0: z=0, а значит для точек |c|>2 на шаг 1 уже не переключится
// На шаге>0: |z|<=2, иначе на этот шаг не переключилось бы
// Тогда |z*z+c| будет максимум 2*2+2=6
// Таким образом чтобы представить целую часть результата вычисления надо максимум 3 бита
// И затем ещё +1 бит в самом начале для знака (+ или -)
const z_int_bits = 4; // 0..31
// А точность (кол-во бит после точки) будет -масштаб_точки+z_extra_precision_bits
// 16 дополнительных бит значит что для заметной ошибки надо минимум столько операций:
// LogN(1+2**-16, 1.5) ~= 26572
// Каждый шаг выполняет несколько операций, но +16 битов это всё равно очень много
const z_extra_precision_bits = 16; // >=0

end.