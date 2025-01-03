/*-----------------------------------------------
 * 请在此处填写你的个人信息
 * 学号:SA24218215
 * 姓名:周勤峰
 * 邮箱:qfzhou@email.ustc.edu.cn
 ------------------------------------------------*/
#include <cuda_runtime.h>
#include <chrono>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>

#define AT(x, y, z) universe[(x) * N * N + (y) * N + z]

// using std::cin, std::cout, std::endl;
// using std::ifstream, std::ofstream;
using namespace std;
// 存活细胞数
int population(int N, char *universe)
{
    int result = 0;
    for (int i = 0; i < N * N * N; i++)
        result += universe[i];
    return result;
}

// 打印世界状态
void print_universe(int N, char *universe)
{
    // 仅在N较小(<= 32)时用于Debug
    if (N > 32)
        return;
    for (int x = 0; x < N; x++)
    {
        for (int y = 0; y < N; y++)
        {
            for (int z = 0; z < N; z++)
            {
                if (AT(x, y, z))
                    cout << "O ";
                else
                    cout << "* ";
            }
            cout << endl;
        }
        cout << endl;
    }
    cout << "population: " << population(N, universe) << endl;
}



__global__ void life3d_kernel(int N, char *universe, char *next)
{
    // 计算当前线程处理的 (x, y, z) 坐标
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int z = blockIdx.z * blockDim.z + threadIdx.z;

    // 确保线程在有效范围内
    if (x < N && y < N && z < N)
    {
        // 计算该细胞的邻居数量
        int alive = 0;
        for (int dx = -1; dx <= 1; dx++)
            for (int dy = -1; dy <= 1; dy++)
                for (int dz = -1; dz <= 1; dz++)
                {
                    if (dx == 0 && dy == 0 && dz == 0)
                        continue;

                    int nx = (x + dx + N) % N;
                    int ny = (y + dy + N) % N;
                    int nz = (z + dz + N) % N;
                    alive += universe[nx * N * N + ny * N + nz];
                }

        // 细胞状态更新规则
        if (universe[x * N * N + y * N + z] && (alive < 5 || alive > 7))
            next[x * N * N + y * N + z] = 0;
        else if (!universe[x * N * N + y * N + z] && alive == 6)
            next[x * N * N + y * N + z] = 1;
        else
            next[x * N * N + y * N + z] = universe[x * N * N + y * N + z];
    }
}

// 核心计算代码，利用 CUDA 将世界向前推进 T 个时刻
void life3d_run(int N, char *universe, int T)
{
    char *next = (char *)malloc(N * N * N);
    char *d_universe, *d_next;

    // 分配设备内存
    cudaMalloc(&d_universe, N * N * N);
    cudaMalloc(&d_next, N * N * N);

    // 将数据从主机拷贝到设备
    cudaMemcpy(d_universe, universe, N * N * N, cudaMemcpyHostToDevice);

    dim3 block(16, 16, 16); // 每个块的线程数
    dim3 grid((N + block.x - 1) / block.x, (N + block.y - 1) / block.y, (N + block.z - 1) / block.z); // 网格维度

    for (int t = 0; t < T; t++)
    {
        // 运行 kernel
        life3d_kernel<<<grid, block>>>(N, d_universe, d_next);

        // 等待 GPU 完成任务
        cudaDeviceSynchronize();

        // 交换 universe 和 next
        char *temp = d_universe;
        d_universe = d_next;
        d_next = temp;
    }

    // 将结果从设备拷贝回主机
    cudaMemcpy(universe, d_universe, N * N * N, cudaMemcpyDeviceToHost);

    // 释放设备内存
    cudaFree(d_universe);
    cudaFree(d_next);
}


// 读取输入文件
void read_file(char *input_file, char *buffer)
{
    ifstream file(input_file, std::ios::binary | std::ios::ate);
    if (!file.is_open())
    {
        cout << "Error: Could not open file " << input_file << std::endl;
        exit(1);
    }
    std::streamsize file_size = file.tellg();
    file.seekg(0, std::ios::beg);
    if (!file.read(buffer, file_size))
    {
        std::cerr << "Error: Could not read file " << input_file << std::endl;
        exit(1);
    }
    file.close();
}

// 写入输出文件
void write_file(char *output_file, char *buffer, int N)
{
    ofstream file(output_file, std::ios::binary | std::ios::trunc);
    if (!file)
    {
        cout << "Error: Could not open file " << output_file << std::endl;
        exit(1);
    }
    file.write(buffer, N * N * N);
    file.close();
}

int main(int argc, char **argv)
{
    // cmd args
    if (argc < 5)
    {
        cout << "usage: ./life3d N T input output" << endl;
        return 1;
    }
    int N = std::stoi(argv[1]);
    int T = std::stoi(argv[2]);
    char *input_file = argv[3];
    char *output_file = argv[4];

    char *universe = (char *)malloc(N * N * N);
    read_file(input_file, universe);

    int start_pop = population(N, universe);
    auto start_time = std::chrono::high_resolution_clock::now();
    life3d_run(N, universe, T);
    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end_time - start_time;
    int final_pop = population(N, universe);
    write_file(output_file, universe, N);

    cout << "start population: " << start_pop << endl;
    cout << "final population: " << final_pop << endl;
    double time = duration.count();
    cout << "time: " << time << "s" << endl;
    cout << "cell per sec: " << T / time * N * N * N << endl;

    free(universe);
    return 0;
}
