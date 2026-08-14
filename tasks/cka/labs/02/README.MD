We have an enterprise application in namespace  **prod-jobs**.<br>
The application fetches tasks for processing from a queue (Kafka).<br>
We need to create **Horizontal Pod Autoscaling** based on **CPU** load.<br>
When the CPU load rises to **100%** we need to increase the number of pods to **6**.<br>
The **minimum** amount of pods should be **2**.<br>
