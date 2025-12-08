// SubdividedPlaneGenerator.cs
using UnityEngine;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class SubdividedPlaneGenerator : MonoBehaviour
{
    [SerializeField] private int resolution = 100;  // 分割数
    [SerializeField] private float size = 10f;      // サイズ
    
    void Start()
    {
        GeneratePlane();
    }
    
    [ContextMenu("Generate Plane")]
    public void GeneratePlane()
    {
        Mesh mesh = new Mesh();
        mesh.name = "Subdivided Plane";
        
        // 頂点数が多い場合は32bitインデックス
        if (resolution > 250)
        {
            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        }
        
        int vertCount = (resolution + 1) * (resolution + 1);
        Vector3[] vertices = new Vector3[vertCount];
        Vector2[] uvs = new Vector2[vertCount];
        
        // 頂点とUV生成
        for (int z = 0; z <= resolution; z++)
        {
            for (int x = 0; x <= resolution; x++)
            {
                int i = z * (resolution + 1) + x;
                float xPos = ((float)x / resolution - 0.5f) * size;
                float zPos = ((float)z / resolution - 0.5f) * size;
                
                vertices[i] = new Vector3(xPos, 0, zPos);
                uvs[i] = new Vector2((float)x / resolution, (float)z / resolution);
            }
        }
        
        // インデックス生成
        int[] triangles = new int[resolution * resolution * 6];
        int tri = 0;
        
        for (int z = 0; z < resolution; z++)
        {
            for (int x = 0; x < resolution; x++)
            {
                int i = z * (resolution + 1) + x;
                
                triangles[tri + 0] = i;
                triangles[tri + 1] = i + resolution + 1;
                triangles[tri + 2] = i + 1;
                
                triangles[tri + 3] = i + 1;
                triangles[tri + 4] = i + resolution + 1;
                triangles[tri + 5] = i + resolution + 2;
                
                tri += 6;
            }
        }
        
        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
        
        GetComponent<MeshFilter>().mesh = mesh;
        
        Debug.Log($"Generated plane: {vertCount} vertices, {triangles.Length / 3} triangles");
    }
}
